<#
.SYNOPSIS
  P3 code-analysis deterministic scanner. Outputs JSON to stdout.

.DESCRIPTION
  Extracts the mechanical scan steps of core.p3-code-analysis.agent.md into a
  testable script. The agent calls this script and interprets the JSON result;
  all semantic analysis / decision making stays in the agent.

  Modes:
    config    : parse .cucb/config.md (repo path table + txCd scan patterns)
    discovery : keyword / class-hint scan across paths, txCd extraction, caller trace
    locate    : find .java files containing a txCd under one src path
    analyze   : exception / boundary / annotation / status-check scans on given files
    callers   : find .java files referencing a class name
    grep      : generic pattern scan (supports -IncludeTests for Cerberus test code)

  Unless -IncludeTests is set, files whose full path matches
  'test|Test|Mock|Stub' are always excluded. Results are deduplicated.

.EXAMPLE
  .\p3-scan.ps1 -Mode config
  .\p3-scan.ps1 -Mode discovery -Keywords ProxyConfig,CBKProxy
  .\p3-scan.ps1 -Mode discovery -ServiceClassHint CustAcdntReptSvc
  .\p3-scan.ps1 -Mode locate -TxCd SZCUA01G001 -SrcPath D:\...\ZCUSvc\src
  .\p3-scan.ps1 -Mode analyze -Files a.java,b.java
  .\p3-scan.ps1 -Mode callers -ClassName DpstDpstSvcListIn
  .\p3-scan.ps1 -Mode grep -Pattern SZCUA01G001 -ScanPaths src\test\java -IncludeTests
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('config', 'discovery', 'locate', 'analyze', 'callers', 'grep', 'dbio')]
    [string]$Mode,

    [string]$ConfigPath = '.cucb/config.md',
    [string[]]$ScanPaths = @(),
    [string[]]$Keywords = @(),
    [string]$ServiceClassHint = '',
    [string]$TxCd = '',
    [string]$SrcPath = '',
    [string[]]$Files = @(),
    [string]$ClassName = '',
    [string]$ExcludeFile = '',
    [string]$Pattern = '',
    [string]$LBSystem = '',
    [switch]$CaseSensitive,
    [switch]$IncludeTests
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$TestExcludeRegex = 'test|Test|Mock|Stub'
$FallbackTxCdPattern = 'SZ[A-Z0-9]{8,14}'

function Out-Json($obj) {
    $obj | ConvertTo-Json -Depth 8
}

function Get-JavaFiles([string[]]$Paths, [switch]$WithTests) {
    $result = @()
    foreach ($p in $Paths) {
        if (-not (Test-Path $p)) { continue }
        $found = Get-ChildItem -Path $p -Recurse -Filter '*.java' -File -ErrorAction SilentlyContinue
        if (-not $WithTests) {
            $found = $found | Where-Object { $_.FullName -notmatch $TestExcludeRegex }
        }
        $result += $found
    }
    return @($result | Sort-Object -Property FullName -Unique)
}

function Get-ConfigData([string]$Path) {
    $data = [ordered]@{
        config_found     = $false
        repo_paths       = @()
        txcd_patterns    = @()
        combined_pattern = $FallbackTxCdPattern
        dao_entries      = @()
    }
    if (-not (Test-Path $Path)) { return $data }
    $data.config_found = $true
    $content = Get-Content $Path -Raw -Encoding UTF8

    # Optional '## DAO 設定' section. DAO mechanism differs per system, so rows are
    # keyed by LBSystem:  | CBK | `D:\git\dao\src` | `*.xml` | dbio 定義 |
    # Legacy bullet form (路徑:/dbio Pattern:) is read as the CBK entry.
    $daoSection = [regex]::Match($content, '##\s*DAO 設定[\s\S]*?(?=\r?\n##\s|\z)')
    if ($daoSection.Success) {
        $daoRows = [regex]::Matches($daoSection.Value, '(?m)^\|\s*([A-Za-z0-9_]+)\s*\|\s*`?([^`|]*?)`?\s*\|\s*`?([^`|]*?)`?\s*\|')
        $data.dao_entries = @($daoRows | Where-Object {
                $_.Groups[1].Value.Trim() -ne 'LBSystem' -and $_.Groups[2].Value.Trim() -notmatch '^-+$'
            } | ForEach-Object {
                [ordered]@{
                    lbsystem = $_.Groups[1].Value.Trim()
                    path     = $_.Groups[2].Value.Trim()
                    glob     = @($_.Groups[3].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                }
            })
        if ($data.dao_entries.Count -eq 0) {
            $pm = [regex]::Match($daoSection.Value, '-\s*路徑:\s*`?([^`\r\n]+?)`?\s*$', 'Multiline')
            $gm = [regex]::Match($daoSection.Value, '-\s*dbio Pattern:\s*`?([^`\r\n]+?)`?\s*$', 'Multiline')
            if ($pm.Success) {
                $legacyGlob = @()
                if ($gm.Success) { $legacyGlob = @($gm.Groups[1].Value.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
                $data.dao_entries = @([ordered]@{ lbsystem = 'CBK'; path = $pm.Groups[1].Value.Trim(); glob = $legacyGlob })
            }
        }
    }

    # Repo path table rows: | `SZCU*` | `D:\path` | CBK | desc |
    $rowMatches = [regex]::Matches($content, '\|\s*`([A-Z]+\*)`\s*\|\s*`?([^`|]+?)`?\s*\|\s*([^|]*)\|')
    $data.repo_paths = @($rowMatches | ForEach-Object {
            [ordered]@{
                prefix   = $_.Groups[1].Value.Trim()
                path     = $_.Groups[2].Value.Trim()
                lbsystem = $_.Groups[3].Value.Trim()
                exists   = [bool](Test-Path $_.Groups[2].Value.Trim())
            }
        })

    # Scan-rule table rows: | CBK | `SZ[A-Z0-9]{9}` | ... (first cell plain word)
    $patMatches = [regex]::Matches($content, '\|\s*\w+\s*\|\s*`([^`]+)`\s*\|')
    $patterns = @($patMatches | ForEach-Object { $_.Groups[1].Value.Trim() } |
            Where-Object { $_ -and $_ -notmatch '^[A-Za-z]:\\' } | Sort-Object -Unique)
    if ($patterns.Count -gt 0) {
        $data.txcd_patterns = $patterns
        $data.combined_pattern = ($patterns -join '|')
    }
    return $data
}

function Get-TxCdsInFile([string]$FilePath, [string]$TxCdPattern) {
    $found = Select-String -Path $FilePath -Pattern $TxCdPattern -AllMatches -ErrorAction SilentlyContinue
    if (-not $found) { return @() }
    return @($found | ForEach-Object { $_.Matches } | ForEach-Object { $_.Value } | Sort-Object -Unique)
}

function Get-MatchEntries($SelectStringResults, [int]$Context = 0) {
    if (-not $SelectStringResults) { return @() }
    return @($SelectStringResults | ForEach-Object {
            $entry = [ordered]@{
                file = $_.Path
                line = $_.LineNumber
                text = $_.Line.Trim()
            }
            if ($Context -gt 0) {
                $raw = @(Get-Content $_.Path -ErrorAction SilentlyContinue)
                $start = [Math]::Max(0, $_.LineNumber - 1 - $Context)
                $end = [Math]::Min($raw.Count - 1, $_.LineNumber - 1 + $Context)
                $entry.context = @($raw[$start..$end])
            }
            $entry
        })
}

switch ($Mode) {

    'config' {
        Out-Json (Get-ConfigData $ConfigPath)
        break
    }

    'discovery' {
        $config = Get-ConfigData $ConfigPath
        $txcdPattern = $config.combined_pattern

        # Resolve scan paths: explicit -ScanPaths wins, else all config.md paths
        $targetPaths = if ($ScanPaths.Count -gt 0) { $ScanPaths } else { @($config.repo_paths | ForEach-Object { $_.path }) }
        $existingPaths = @($targetPaths | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique)

        if ($existingPaths.Count -eq 0) {
            Out-Json ([ordered]@{ discovery_status = 'LocalPathNotConfigured'; searched_paths = @($targetPaths); candidates = @() })
            break
        }

        $hitFiles = @()
        $hintMode = -not [string]::IsNullOrWhiteSpace($ServiceClassHint)

        if ($hintMode) {
            # Exact filename match, then fuzzy
            $allJava = Get-JavaFiles $existingPaths
            $hitFiles = @($allJava | Where-Object { $_.Name -eq "$ServiceClassHint.java" })
            $matchType = 'exact'
            if ($hitFiles.Count -eq 0) {
                $hitFiles = @($allJava | Where-Object { $_.Name -like "*$ServiceClassHint*" })
                $matchType = 'fuzzy'
            }
            if ($hitFiles.Count -eq 0) {
                Out-Json ([ordered]@{
                        discovery_status   = 'ServiceClassNotFound'
                        service_class_hint = $ServiceClassHint
                        searched_paths     = @($existingPaths)
                        candidates         = @()
                    })
                break
            }
        }
        else {
            if ($Keywords.Count -eq 0) {
                Out-Json ([ordered]@{ error = 'discovery mode requires -Keywords or -ServiceClassHint' })
                break
            }
            $allJava = Get-JavaFiles $existingPaths
            $matchType = 'keyword'
            $hitSet = @{}
            foreach ($kw in $Keywords) {
                $hits = $allJava | Select-String -Pattern ([regex]::Escape($kw)) -List -ErrorAction SilentlyContinue
                foreach ($h in $hits) { $hitSet[$h.Path] = $true }
            }
            $hitFiles = @($allJava | Where-Object { $hitSet.ContainsKey($_.FullName) })
        }

        # Extract txCds per hit file; caller-trace Config/Enum-like files with no txCd
        $fileResults = @()
        foreach ($f in $hitFiles) {
            $txcds = Get-TxCdsInFile $f.FullName $txcdPattern
            $source = 'direct'

            if ($txcds.Count -eq 0) {
                $looksConfig = $f.BaseName -match 'Config|Enum|Constant|Properties|Setting'
                if (-not $looksConfig) {
                    $head = (Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue)
                    $looksConfig = $head -match 'enum |@ConfigurationProperties|@Value|interface.*Code'
                }
                if ($looksConfig) {
                    $callerHits = Get-JavaFiles $existingPaths |
                        Where-Object { $_.FullName -ne $f.FullName } |
                        Select-String -Pattern $f.BaseName -CaseSensitive -List -ErrorAction SilentlyContinue
                    $callerTx = @()
                    foreach ($c in $callerHits) { $callerTx += Get-TxCdsInFile $c.Path $txcdPattern }
                    if ($callerTx.Count -gt 0) {
                        $txcds = @($callerTx | Sort-Object -Unique)
                        $source = 'caller_trace'
                    }
                }
            }
            $fileResults += [ordered]@{ file = $f.FullName; txcds = @($txcds); source = $source }
        }

        # Group by scan path root
        $candidates = @()
        foreach ($root in $existingPaths) {
            $inRoot = @($fileResults | Where-Object { $_.file -like "$root*" })
            if ($inRoot.Count -eq 0) { continue }
            $rootTx = @($inRoot | ForEach-Object { $_.txcds } | Sort-Object -Unique)
            $candidates += [ordered]@{
                local_path       = $root
                hit_files        = @($inRoot | ForEach-Object { $_.file })
                discovered_txcds = $rootTx
                txcd_source      = if (@($inRoot | Where-Object { $_.source -eq 'caller_trace' }).Count -gt 0) { 'caller_trace' } else { 'direct' }
                hit_count        = $inRoot.Count
            }
        }

        $allTx = @($candidates | ForEach-Object { $_.discovered_txcds } | Sort-Object -Unique)
        $status = if ($candidates.Count -eq 0) { 'ModuleNotFound' }
        elseif ($candidates.Count -eq 1 -and $allTx.Count -ge 1) { 'Discovered' }
        else { 'ModuleAmbiguous' }

        Out-Json ([ordered]@{
                discovery_status = $status
                match_type       = $matchType
                keywords         = @($Keywords)
                searched_paths   = @($existingPaths)
                candidates       = $candidates
            })
        break
    }

    'locate' {
        if (-not $TxCd -or -not $SrcPath) {
            Out-Json ([ordered]@{ error = 'locate mode requires -TxCd and -SrcPath' }); break
        }
        if (-not (Test-Path $SrcPath)) {
            Out-Json ([ordered]@{ txCd = $TxCd; src_path = $SrcPath; status = 'PathNotFound'; files = @() }); break
        }
        $hits = Get-JavaFiles @($SrcPath) | Select-String -Pattern $TxCd -List -ErrorAction SilentlyContinue
        $paths = @($hits | ForEach-Object { $_.Path } | Sort-Object -Unique)
        Out-Json ([ordered]@{
                txCd     = $TxCd
                src_path = $SrcPath
                status   = if ($paths.Count -gt 0) { 'Found' } else { 'SourceNotFound' }
                files    = $paths
            })
        break
    }

    'dbio' {
        # Resolve dbio definition files in the DAO repo and extract SQL table access.
        # -Keywords: dbio ids / DAO method names the service code references (from P3's reading).
        # -ScanPaths overrides config.md '## DAO 設定' path; -Pattern overrides dbio glob (comma-separated).
        if ($Keywords.Count -eq 0) {
            Out-Json ([ordered]@{ error = 'dbio mode requires -Keywords (dbio ids or DAO method names)' }); break
        }
        $config = Get-ConfigData $ConfigPath
        $sys = if ($LBSystem) { $LBSystem } else { 'CBK' }
        $daoEntry = $config.dao_entries | Where-Object { $_.lbsystem -eq $sys } | Select-Object -First 1
        $daoPaths = if ($ScanPaths.Count -gt 0) { $ScanPaths } elseif ($null -ne $daoEntry -and $daoEntry.path) { @($daoEntry.path) } else { @() }
        $daoPaths = @($daoPaths | Where-Object { $_ -and (Test-Path $_) })
        if ($daoPaths.Count -eq 0) {
            Out-Json ([ordered]@{
                    status   = 'DaoPathNotConfigured'
                    lbsystem = $sys
                    files    = @()
                    note     = "config.md ## DAO 設定 無 $sys 的可用路徑（該系統 DAO 機制未設定或路徑不存在）"
                }); break
        }
        $globs = if ($Pattern) { @($Pattern.Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
        elseif ($null -ne $daoEntry -and $daoEntry.glob.Count -gt 0) { $daoEntry.glob }
        else { @('*.xml', '*.dbio', '*.sql') }

        $candidateFiles = @()
        foreach ($p in $daoPaths) {
            foreach ($g in $globs) {
                $candidateFiles += Get-ChildItem -Path $p -Recurse -Filter $g -File -ErrorAction SilentlyContinue
            }
        }
        $candidateFiles = @($candidateFiles | Sort-Object -Property FullName -Unique)

        $tableRegex = '(?i)\b(?:FROM|JOIN|INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE\s+INTO)\s+([A-Za-z_][\w.$#]*)'
        $writeRegex = '(?i)\b(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM|MERGE\s+INTO)\s+([A-Za-z_][\w.$#]*)'
        $results = @()
        foreach ($kw in $Keywords) {
            $hits = $candidateFiles | Select-String -Pattern ([regex]::Escape($kw)) -List -ErrorAction SilentlyContinue
            foreach ($h in $hits) {
                $raw = Get-Content $h.Path -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($null -eq $raw) { $raw = '' }
                $writeTables = @([regex]::Matches($raw, $writeRegex) | ForEach-Object { $_.Groups[1].Value.ToUpper() } | Sort-Object -Unique)
                $allTables = @([regex]::Matches($raw, $tableRegex) | ForEach-Object { $_.Groups[1].Value.ToUpper() } |
                        Where-Object { $_ -notmatch '^(SELECT|DUAL|WHERE|SET)$' } | Sort-Object -Unique)
                $tables = @($allTables | ForEach-Object {
                        $op = 'R'
                        if ($writeTables -contains $_) { $op = 'W' }
                        [ordered]@{ table = $_; op = $op }
                    })
                $results += [ordered]@{ keyword = $kw; file = $h.Path; tables = $tables }
            }
        }
        Out-Json ([ordered]@{
                status         = if ($results.Count -gt 0) { 'Found' } else { 'DbioNotFound' }
                searched_paths = $daoPaths
                globs          = $globs
                results        = $results
            })
        break
    }

    'analyze' {
        $targets = @($Files | Where-Object { Test-Path $_ })
        if ($targets.Count -eq 0) {
            Out-Json ([ordered]@{ error = 'analyze mode requires -Files (existing files)' }); break
        }
        $scans = [ordered]@{
            exceptions     = [ordered]@{ pattern = 'throw\s+new\s+\w*Exception\s*\(\s*"([A-Z0-9]+)"'; context = 5 }
            numeric_bounds = [ordered]@{ pattern = '(>=|<=|>|<)\s*\d+(\.\d+)?'; context = 3 }
            annotations    = [ordered]@{ pattern = '@(NotNull|NotBlank|NotEmpty|Size|Max|Min|Length|Pattern|Digits)\b'; context = 0 }
            status_checks  = [ordered]@{ pattern = '\.(getStatus|getAcctSts|getCustSts|getState|getStsCd)\(\)'; context = 3 }
        }
        $result = [ordered]@{ analyzed_files = $targets }
        foreach ($key in $scans.Keys) {
            $hits = Select-String -Path $targets -Pattern $scans[$key].pattern -AllMatches -ErrorAction SilentlyContinue
            $result[$key] = @(Get-MatchEntries $hits -Context $scans[$key].context)
        }
        Out-Json $result
        break
    }

    'callers' {
        if (-not $ClassName) {
            Out-Json ([ordered]@{ error = 'callers mode requires -ClassName' }); break
        }
        $config = Get-ConfigData $ConfigPath
        $targetPaths = if ($ScanPaths.Count -gt 0) { $ScanPaths } else { @($config.repo_paths | ForEach-Object { $_.path }) }
        $existingPaths = @($targetPaths | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique)

        $callerFiles = Get-JavaFiles $existingPaths |
            Where-Object { $_.BaseName -ne $ClassName -and $_.FullName -ne $ExcludeFile } |
            Select-String -Pattern $ClassName -CaseSensitive -List -ErrorAction SilentlyContinue
        $callers = @($callerFiles | ForEach-Object {
                [ordered]@{
                    file  = $_.Path
                    txcds = @(Get-TxCdsInFile $_.Path $config.combined_pattern)
                }
            })
        Out-Json ([ordered]@{
                class_name     = $ClassName
                searched_paths = @($existingPaths)
                callers        = $callers
            })
        break
    }

    'grep' {
        if (-not $Pattern) {
            Out-Json ([ordered]@{ error = 'grep mode requires -Pattern' }); break
        }
        $targets = @()
        if ($Files.Count -gt 0) {
            $targets = @($Files | Where-Object { Test-Path $_ })
        }
        else {
            $targets = @((Get-JavaFiles $ScanPaths -WithTests:$IncludeTests) | ForEach-Object { $_.FullName })
        }
        if ($targets.Count -eq 0) {
            Out-Json ([ordered]@{ pattern = $Pattern; matches = @() }); break
        }
        $hits = Select-String -Path $targets -Pattern $Pattern -CaseSensitive:$CaseSensitive -AllMatches -ErrorAction SilentlyContinue
        Out-Json ([ordered]@{
                pattern = $Pattern
                matches = @(Get-MatchEntries $hits)
            })
        break
    }
}
