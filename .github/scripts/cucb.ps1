<#
.SYNOPSIS
  Cerberus plan state machine + mechanical quality-gate checks. Outputs JSON to stdout.

.DESCRIPTION
  Extracts the deterministic parts of the Cerberus orchestrator into a testable
  script: plan lifecycle (init / next / update / decisions), P2 mechanical checks
  (txCd presence, source content, path health, existing-implementation scan,
  capability staleness) and output verification. All semantic judgment stays in
  the agents; the orchestrator calls this script instead of hand-editing plan
  markdown.

  Plan state lives in .cucb/plans/<id>_active.plan.json (source of truth).
  A human-readable <id>_active.plan.md is regenerated on every save.

  Modes:
    plan-init       : create a new active plan after P1 (fetch-requirement)
    plan-next       : return the next actionable step + assembled context
    plan-update     : set a step's status / produced files
    plan-set        : merge JSON into a plan section (e.g. quality_gate)
    plan-state      : set plan state (Active / Paused / Completed)
    decision-add    : record a user decision (clarification / p3 / feasibility)
    note-add        : append a note (quality gate notes, background info)
    gate-p2         : mechanical P2 checks, outputs facts as JSON
    capability-scan : build/refresh .cucb/step-capabilities.md
    verify-outputs  : check produced files exist and are non-empty

.EXAMPLE
  .\cucb.ps1 -Mode plan-init -RequirementId CEPRJ-3612 -PageTitle "好友轉帳" -SourcePaths .cucb/requirement-specs/sources/CEPRJ-3612.md -TxCds SZCUA01G001
  .\cucb.ps1 -Mode plan-next
  .\cucb.ps1 -Mode plan-update -Step P3 -Status done -Files .cucb/code-analysis/SZCUA01G001-analysis.md
  .\cucb.ps1 -Mode plan-set -Section quality_gate -Json '{"requirement_type":"api_change"}'
  .\cucb.ps1 -Mode decision-add -DecisionType feasibility -Id AC-04 -Decision manual -Note "BXM 環境未就緒"
  .\cucb.ps1 -Mode gate-p2
  .\cucb.ps1 -Mode verify-outputs -Files src/test/resources/features/foo.feature
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('plan-init', 'plan-next', 'plan-update', 'plan-set', 'plan-state',
        'decision-add', 'note-add', 'gate-p2', 'capability-scan', 'verify-outputs',
        'verify-build', 'answer-add')]
    [string]$Mode,

    [string]$PlanDir = '.cucb/plans',
    [string]$ConfigPath = '.cucb/config.md',
    [string]$DevConfPath = 'src/test/resources/dev.conf',
    [string]$StepDir = 'src/test/java/com/yhao/step',
    [string]$FeatureDir = 'src/test/resources/features',
    [string]$CapabilityPath = '.cucb/step-capabilities.md',

    [string]$RequirementId = '',
    [string]$PageTitle = '',
    [string]$EnvName = 'dev',
    [string[]]$SourcePaths = @(),
    [string[]]$TxCds = @(),

    [string]$Step = '',
    [ValidateSet('', 'pending', 'done', 'skipped', 'waiting', 'blocked')]
    [string]$Status = '',
    [string[]]$Files = @(),

    [string]$Section = '',
    [string]$Json = '',
    [string]$JsonFile = '',

    [ValidateSet('', 'clarification', 'p3_confirmation', 'feasibility')]
    [string]$DecisionType = '',
    [string]$Id = '',
    [string]$Decision = '',
    [string]$Note = '',
    [string]$Text = '',
    [ValidateSet('', 'Active', 'Paused', 'Completed')]
    [string]$PlanState = '',
    [string]$Tag = '',
    [string]$AnswersPath = '.cucb/feasibility-answers.md',
    [switch]$SkipCompile,
    [switch]$Rebuild
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$StepDefs = @(
    @{ id = 'P1'; agent = 'fetch-requirement' },
    @{ id = 'P2'; agent = 'core.p2-quality-gate' },
    @{ id = 'P3'; agent = 'core.p3-code-analysis' },
    @{ id = 'P4'; agent = 'core.p4-organize' },
    @{ id = 'P5'; agent = 'core.p5-feature' },
    @{ id = 'P6'; agent = 'core.p6-step' },
    @{ id = 'P7'; agent = 'core.p7-review' }
)
$MdSymbols = @{ done = '[x]'; pending = '[ ]'; skipped = '[~]'; waiting = '[!]'; blocked = '[!]' }
$ProgressSymbols = @{ done = '✅'; pending = '○'; skipped = '~'; waiting = '⚠️'; blocked = '⚠️' }

function Out-Json($obj) {
    ConvertTo-Json -InputObject $obj -Depth 12
}

function Fail([string]$msg) {
    Out-Json ([ordered]@{ ok = $false; error = $msg })
    exit 1
}

# ---------- plan persistence ----------

function Get-ActivePlanFile {
    if (-not (Test-Path $PlanDir)) { return $null }
    return Get-ChildItem $PlanDir -Filter '*_active.plan.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Read-Plan {
    $f = Get-ActivePlanFile
    if ($null -eq $f) { Fail "No active plan under $PlanDir. Run -Mode plan-init first." }
    $plan = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    return @{ plan = $plan; path = $f.FullName }
}

function Format-PlanMarkdown($plan) {
    $L = New-Object System.Collections.Generic.List[string]
    $L.Add("# Cerberus Plan - $($plan.requirement_id)")
    $L.Add('')
    $L.Add('> 本檔由 cucb.ps1 自動產生，請勿手動編輯；狀態以同名 .json 為準。')
    $L.Add('')
    $L.Add('## Metadata')
    $L.Add('| 欄位 | 值 |')
    $L.Add('|------|---|')
    $L.Add("| Requirement ID | $($plan.requirement_id) |")
    $L.Add("| Page Title | $($plan.page_title) |")
    $L.Add("| Env | $($plan.env) |")
    $L.Add("| State | $($plan.state) |")
    $L.Add("| Created At | $($plan.created_at) |")
    $L.Add("| Updated At | $($plan.updated_at) |")
    $L.Add("| 交易代碼 | $(@($plan.txcd_list) -join ', ') |")
    $L.Add('')
    $L.Add('## Execution Plan')
    $L.Add('| Step | Agent | Status | Produced Files |')
    $L.Add('|------|-------|--------|----------------|')
    foreach ($s in $plan.steps) {
        $sym = $MdSymbols[[string]$s.status]
        $L.Add("| $($s.id) | $($s.agent) | $sym $($s.status) | $(@($s.files) -join '<br>') |")
    }
    $L.Add('')
    $qg = $plan.quality_gate
    if ($null -ne $qg -and @($qg.PSObject.Properties).Count -gt 0) {
        $L.Add('## Quality Gate')
        foreach ($p in $qg.PSObject.Properties) {
            if ($p.Name -eq 'path_health') { continue }
            $v = $p.Value
            if ($v -is [Array]) { $v = @($v) -join ', ' }
            $L.Add("- **$($p.Name)**: $v")
        }
        if ($null -ne $qg.PSObject.Properties['path_health'] -and @($qg.path_health).Count -gt 0) {
            $L.Add('')
            $L.Add('### Path Health')
            $L.Add('| txCd | status | path | LBSystem |')
            $L.Add('|------|--------|------|----------|')
            foreach ($h in @($qg.path_health)) {
                $L.Add("| $($h.txCd) | $($h.status) | $($h.path) | $($h.lbsystem) |")
            }
        }
        $L.Add('')
    }
    $L.Add('## User Decisions')
    $L.Add('')
    $L.Add('### user_clarifications')
    $L.Add('| # | 問題摘要 | 使用者回答 |')
    $L.Add('|---|---------|-----------|')
    $i = 0
    foreach ($d in @($plan.decisions.clarifications)) {
        $i++; $L.Add("| $i | $($d.note) | $($d.decision) |")
    }
    $L.Add('')
    $L.Add('### p3_confirmations')
    $L.Add('| ID | decision | note |')
    $L.Add('|----|----------|------|')
    foreach ($d in @($plan.decisions.p3_confirmations)) {
        $L.Add("| $($d.id) | $($d.decision) | $($d.note) |")
    }
    $L.Add('')
    $L.Add('### feasibility_decisions')
    $L.Add('| AC ID | decision | note |')
    $L.Add('|-------|----------|------|')
    foreach ($d in @($plan.decisions.feasibility_decisions)) {
        $L.Add("| $($d.id) | $($d.decision) | $($d.note) |")
    }
    $L.Add('')
    $L.Add('## Notes')
    foreach ($n in @($plan.notes)) { $L.Add("- [$($n.time)] $($n.text)") }
    if (@($plan.notes).Count -eq 0) { $L.Add('（無）') }
    $L.Add('')
    $L.Add('## Blockers')
    foreach ($b in @($plan.blockers)) { $L.Add("- $b") }
    if (@($plan.blockers).Count -eq 0) { $L.Add('（無）') }
    return ($L -join "`r`n")
}

function Save-Plan($plan, [string]$jsonPath) {
    $plan.updated_at = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    Set-Content -Path $jsonPath -Value (ConvertTo-Json -InputObject $plan -Depth 12) -Encoding UTF8
    $mdPath = $jsonPath -replace '\.json$', '.md'
    Set-Content -Path $mdPath -Value (Format-PlanMarkdown $plan) -Encoding UTF8
}

function Get-ProgressLine($plan, [string]$currentStep) {
    $parts = @()
    foreach ($s in $plan.steps) {
        $sym = $ProgressSymbols[[string]$s.status]
        if ($s.id -eq $currentStep) { $sym = '⏳' }
        $parts += "$($s.id)$sym"
    }
    return ($parts -join ' -> ')
}

# ---------- config parsing (same table format as p3-scan.ps1) ----------

function Get-ConfigData([string]$Path) {
    $data = [ordered]@{ config_found = $false; repo_paths = @() }
    if (-not (Test-Path $Path)) { return $data }
    $data.config_found = $true
    $content = Get-Content $Path -Raw -Encoding UTF8
    $rowMatches = [regex]::Matches($content, '\|\s*`([A-Z]+\*)`\s*\|\s*`?([^`|]+?)`?\s*\|\s*([^|]*)\|')
    $data.repo_paths = @($rowMatches | ForEach-Object {
            [ordered]@{
                prefix   = $_.Groups[1].Value.Trim()
                path     = $_.Groups[2].Value.Trim()
                lbsystem = $_.Groups[3].Value.Trim()
            }
        })
    return $data
}

function Find-FilesContaining([string]$Dir, [string]$Literal, [string]$Filter) {
    if (-not (Test-Path $Dir)) { return @() }
    $hits = Get-ChildItem $Dir -Recurse -File -Filter $Filter -ErrorAction SilentlyContinue |
        Select-String -Pattern ([regex]::Escape($Literal)) -List -ErrorAction SilentlyContinue
    return @($hits | ForEach-Object { $_.Path } | Sort-Object -Unique)
}

function Get-CapabilityStatus {
    $stepFiles = @(Get-ChildItem $StepDir -Filter '*.java' -File -ErrorAction SilentlyContinue)
    $exists = Test-Path $CapabilityPath
    $stale = -not $exists
    if ($exists -and $stepFiles.Count -gt 0) {
        $capItem = Get-Item $CapabilityPath
        $newer = @($stepFiles | Where-Object { $_.LastWriteTime -gt $capItem.LastWriteTime })
        $blocks = @(Select-String -Path $CapabilityPath -Pattern '^## .*\.java$' -ErrorAction SilentlyContinue)
        $stale = ($newer.Count -gt 0) -or ($blocks.Count -ne $stepFiles.Count)
    }
    return [ordered]@{
        path            = $CapabilityPath
        exists          = $exists
        stale           = [bool]$stale
        step_file_count = $stepFiles.Count
    }
}

# ---------- modes ----------

switch ($Mode) {

    'plan-init' {
        if (-not $RequirementId) { Fail 'plan-init requires -RequirementId' }
        if (-not (Test-Path $PlanDir)) { New-Item -ItemType Directory -Force -Path $PlanDir | Out-Null }
        $now = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
        $steps = @()
        foreach ($def in $StepDefs) {
            $steps += [pscustomobject]@{ id = $def.id; agent = $def.agent; status = 'pending'; files = @() }
        }
        $steps[0].status = 'done'
        $steps[0].files = @($SourcePaths)
        $plan = [pscustomobject]@{
            requirement_id = $RequirementId
            page_title     = $PageTitle
            env            = $EnvName
            created_at     = $now
            updated_at     = $now
            state          = 'Active'
            txcd_list      = @($TxCds)
            source_paths   = @($SourcePaths)
            steps          = $steps
            quality_gate   = [pscustomobject]@{}
            decisions      = [pscustomobject]@{
                clarifications        = @()
                p3_confirmations      = @()
                feasibility_decisions = @()
            }
            notes          = @()
            blockers       = @()
        }
        $jsonPath = Join-Path $PlanDir "${RequirementId}_active.plan.json"
        Save-Plan $plan $jsonPath
        Out-Json ([ordered]@{ ok = $true; plan_path = $jsonPath; requirement_id = $RequirementId })
        break
    }

    'plan-next' {
        $r = Read-Plan
        $plan = $r.plan
        $next = $plan.steps | Where-Object { $_.status -in @('pending', 'waiting', 'blocked') } | Select-Object -First 1
        $filesByStep = [ordered]@{}
        foreach ($s in $plan.steps) { $filesByStep[$s.id] = @($s.files) }
        $nextInfo = $null
        $currentId = ''
        if ($null -ne $next) {
            $nextInfo = [ordered]@{ id = $next.id; agent = $next.agent; status = $next.status }
            $currentId = $next.id
        }
        Out-Json ([ordered]@{
                ok             = $true
                plan_path      = $r.path
                requirement_id = $plan.requirement_id
                page_title     = $plan.page_title
                env            = $plan.env
                state          = $plan.state
                progress       = (Get-ProgressLine $plan $currentId)
                next_step      = $nextInfo
                all_done       = ($null -eq $next)
                txcd_list      = @($plan.txcd_list)
                source_paths   = @($plan.source_paths)
                quality_gate   = $plan.quality_gate
                decisions      = $plan.decisions
                files_by_step  = $filesByStep
                notes          = @($plan.notes)
            })
        break
    }

    'plan-update' {
        if (-not $Step -or -not $Status) { Fail 'plan-update requires -Step and -Status' }
        $r = Read-Plan
        $plan = $r.plan
        $target = $plan.steps | Where-Object { $_.id -eq $Step } | Select-Object -First 1
        if ($null -eq $target) { Fail "Unknown step: $Step" }
        $target.status = $Status
        if ($Files.Count -gt 0) { $target.files = @($Files) }
        Save-Plan $plan $r.path
        Out-Json ([ordered]@{ ok = $true; step = $Step; status = $Status; progress = (Get-ProgressLine $plan '') })
        break
    }

    'plan-set' {
        if (-not $Section) { Fail 'plan-set requires -Section' }
        $raw = $Json
        if (-not $raw -and $JsonFile) { $raw = Get-Content $JsonFile -Raw -Encoding UTF8 }
        if (-not $raw) { Fail 'plan-set requires -Json or -JsonFile' }
        $patch = $raw | ConvertFrom-Json
        $r = Read-Plan
        $plan = $r.plan
        $existing = $plan.PSObject.Properties[$Section]
        if ($patch -is [Array]) {
            if ($null -eq $existing) {
                $plan | Add-Member -NotePropertyName $Section -NotePropertyValue @($patch)
            } else {
                $plan.$Section = @($patch)
            }
        } elseif ($null -eq $existing -or $existing.Value -isnot [System.Management.Automation.PSCustomObject]) {
            $plan | Add-Member -NotePropertyName $Section -NotePropertyValue $patch -Force
        } else {
            foreach ($p in $patch.PSObject.Properties) {
                $plan.$Section | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
            }
        }
        Save-Plan $plan $r.path
        Out-Json ([ordered]@{ ok = $true; section = $Section })
        break
    }

    'plan-state' {
        if (-not $PlanState) { Fail 'plan-state requires -PlanState' }
        $r = Read-Plan
        $r.plan.state = $PlanState
        Save-Plan $r.plan $r.path
        Out-Json ([ordered]@{ ok = $true; state = $PlanState })
        break
    }

    'decision-add' {
        if (-not $DecisionType -or -not $Decision) { Fail 'decision-add requires -DecisionType and -Decision' }
        $r = Read-Plan
        $plan = $r.plan
        $entry = [pscustomobject]@{
            id       = $Id
            decision = $Decision
            note     = $Note
            time     = (Get-Date).ToString('yyyy-MM-dd HH:mm')
        }
        switch ($DecisionType) {
            'clarification' { $plan.decisions.clarifications += $entry }
            'p3_confirmation' { $plan.decisions.p3_confirmations += $entry }
            'feasibility' { $plan.decisions.feasibility_decisions += $entry }
        }
        Save-Plan $plan $r.path
        Out-Json ([ordered]@{ ok = $true; type = $DecisionType; id = $Id })
        break
    }

    'note-add' {
        if (-not $Text) { Fail 'note-add requires -Text' }
        $r = Read-Plan
        $r.plan.notes += [pscustomobject]@{
            time = (Get-Date).ToString('yyyy-MM-dd HH:mm')
            text = $Text
        }
        Save-Plan $r.plan $r.path
        Out-Json ([ordered]@{ ok = $true })
        break
    }

    'gate-p2' {
        # Fall back to the active plan for txCds / sources when params are omitted.
        $txcds = @($TxCds)
        $sources = @($SourcePaths)
        if (($txcds.Count -eq 0 -or $sources.Count -eq 0) -and $null -ne (Get-ActivePlanFile)) {
            $plan = (Read-Plan).plan
            if ($txcds.Count -eq 0) { $txcds = @($plan.txcd_list) }
            if ($sources.Count -eq 0) { $sources = @($plan.source_paths) }
        }

        # Q2 facts: does each source have real content?
        $q2 = @()
        foreach ($p in $sources) {
            $exists = Test-Path $p
            $chars = 0; $lines = 0
            if ($exists) {
                $rawText = Get-Content $p -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($null -eq $rawText) { $rawText = '' }
                $chars = ($rawText -replace '\s', '').Length
                $lines = @($rawText -split "`n").Count
            }
            $verdict = 'ok'
            if (-not $exists) { $verdict = 'missing' }
            elseif ($chars -lt 20) { $verdict = 'empty' }
            elseif ($chars -lt 120) { $verdict = 'minimal' }
            $q2 += [ordered]@{ path = $p; exists = $exists; chars = $chars; lines = $lines; verdict = $verdict }
        }

        # Setup capabilities registered in step-capabilities.md (for P2 precondition pre-screen).
        $canSetup = @()
        if (Test-Path $CapabilityPath) {
            $canSetup = @(Select-String -Path $CapabilityPath -Pattern '^\*\*can_setup\*\*：(.+)$' -ErrorAction SilentlyContinue |
                    ForEach-Object { $_.Matches[0].Groups[1].Value.Trim() } |
                    Where-Object { $_ -and $_ -ne '（無）' })
        }

        # Existing implementation scan per txCd.
        $existingFeatures = @()
        $existingSteps = @()
        foreach ($t in $txcds) {
            $existingFeatures += Find-FilesContaining $FeatureDir $t '*.feature'
            $existingSteps += Find-FilesContaining $StepDir $t '*.java'
        }
        $existingFeatures = @($existingFeatures | Sort-Object -Unique)
        $existingSteps = @($existingSteps | Sort-Object -Unique)

        # Path & connection health per txCd.
        $config = Get-ConfigData $ConfigPath
        $devConfRaw = ''
        if (Test-Path $DevConfPath) { $devConfRaw = Get-Content $DevConfPath -Raw -Encoding UTF8 }
        $health = @()
        foreach ($t in $txcds) {
            $entry = [ordered]@{ txCd = $t; status = ''; prefix = $null; path = $null; lbsystem = $null }
            if (-not $config.config_found) {
                $entry.status = 'config_missing'
            } else {
                $matched = $config.repo_paths | Where-Object { $t -like $_.prefix } | Select-Object -First 1
                if ($null -eq $matched) { $entry.status = 'prefix_not_configured' }
                else {
                    $entry.prefix = $matched.prefix
                    $entry.path = $matched.path
                    $entry.lbsystem = $matched.lbsystem
                    if (-not (Test-Path $matched.path)) { $entry.status = 'path_not_found' }
                    elseif ([string]::IsNullOrWhiteSpace($matched.lbsystem)) { $entry.status = 'lbsystem_not_configured' }
                    elseif ($devConfRaw -notmatch [regex]::Escape($matched.lbsystem)) { $entry.status = 'endpoint_not_configured' }
                    else { $entry.status = 'ok' }
                }
            }
            $health += $entry
        }

        Out-Json ([ordered]@{
                ok                = $true
                q1_txcd_present   = ($txcds.Count -gt 0)
                txcd_list         = $txcds
                q2_sources        = $q2
                existing_features = $existingFeatures
                existing_steps    = $existingSteps
                path_health       = $health
                capabilities      = (Get-CapabilityStatus)
                can_setup         = $canSetup
            })
        break
    }

    'capability-scan' {
        $capStatus = Get-CapabilityStatus
        if (-not $capStatus.stale -and -not $Rebuild) {
            Out-Json ([ordered]@{ ok = $true; rebuilt = $false; capabilities = $capStatus })
            break
        }
        $capDir = Split-Path $CapabilityPath -Parent
        if ($capDir -and -not (Test-Path $capDir)) { New-Item -ItemType Directory -Force -Path $capDir | Out-Null }

        $setupRegex = '(?i)customer|account|acct|card|exist|active|regist|approv|prepared|setup|客戶|帳[戶號]|前置|建立|既有'
        $actionRegex = '(?i)^(a |an |the )?(i|we|user|system)?\s*(call|invoke|send|submit|query|request)'
        $stepFiles = @(Get-ChildItem $StepDir -Filter '*.java' -File -ErrorAction SilentlyContinue | Sort-Object Name)

        $L = New-Object System.Collections.Generic.List[string]
        $L.Add('# Step Capabilities Registry')
        $L.Add("Last updated: $((Get-Date).ToString('yyyy-MM-dd HH:mm'))")
        $L.Add('')
        $filesOut = @()
        foreach ($f in $stepFiles) {
            $raw = Get-Content $f.FullName -Raw -Encoding UTF8
            $givens = @([regex]::Matches($raw, '@Given\s*\(\s*"((?:[^"\\]|\\.)*)"') | ForEach-Object { $_.Groups[1].Value })
            $codes = @([regex]::Matches($raw, 'CBKServiceCode\.([A-Za-z0-9_]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
            $canSetup = @($givens | Where-Object { $_ -match $setupRegex -and $_ -notmatch $actionRegex })
            $L.Add("## $($f.Name)")
            $L.Add('| Given / Setup 能力 | 支援 txCd |')
            $L.Add('|--------------------|-----------|')
            $codeLabel = '通用'
            if ($codes.Count -gt 0) { $codeLabel = ($codes -join ', ') }
            foreach ($g in $givens) { $L.Add("| ``$g`` | $codeLabel |") }
            if ($givens.Count -eq 0) { $L.Add('| （無 @Given） | — |') }
            $setupLabel = '（無）'
            if ($canSetup.Count -gt 0) { $setupLabel = ($canSetup -join '；') }
            $L.Add('')
            $L.Add("**can_setup**：$setupLabel")
            $L.Add('')
            $filesOut += [ordered]@{
                file      = $f.Name
                givens    = $givens
                codes     = $codes
                can_setup = $canSetup
            }
        }
        if ($stepFiles.Count -eq 0) {
            $L.Add('（step 目錄為空，尚無任何前置建立能力）')
        }
        Set-Content -Path $CapabilityPath -Value ($L -join "`r`n") -Encoding UTF8
        Out-Json ([ordered]@{
                ok           = $true
                rebuilt      = $true
                path         = $CapabilityPath
                step_files   = $stepFiles.Count
                capabilities = $filesOut
            })
        break
    }

    'verify-outputs' {
        if ($Files.Count -eq 0) { Fail 'verify-outputs requires -Files' }
        $results = @()
        $allOk = $true
        foreach ($p in $Files) {
            $exists = Test-Path $p
            $bytes = 0
            if ($exists) { $bytes = (Get-Item $p).Length }
            $ok = $exists -and ($bytes -gt 0)
            if (-not $ok) { $allOk = $false }
            $results += [ordered]@{ path = $p; exists = $exists; bytes = $bytes; ok = $ok }
        }
        Out-Json ([ordered]@{ ok = $allOk; files = $results })
        break
    }

    'verify-build' {
        # Deterministic quality gate between P6 and P7:
        #   lint    : feature-file convention checks (-Files)
        #   binding : approximate feature-step <-> step-definition matching (-Files + StepDir)
        #   compile : mvn test-compile (skip with -SkipCompile)
        #   dry_run : cucumber dry-run for the given -Tag (needs JUnit Platform property support)
        $lintIssues = @()
        $featureSteps = @()
        foreach ($f in $Files) {
            if (-not (Test-Path $f)) {
                $lintIssues += [ordered]@{ file = $f; line = 0; issue = 'file_missing' }
                continue
            }
            $raw = Get-Content $f -Raw -Encoding UTF8
            $rawLines = @(Get-Content $f -Encoding UTF8)
            if ($raw -notmatch '(?m)^\s*Feature:') {
                $lintIssues += [ordered]@{ file = $f; line = 0; issue = 'missing_feature_keyword' }
            }
            for ($i = 0; $i -lt $rawLines.Count; $i++) {
                $ln = $rawLines[$i]
                if ($ln -match '^\s*(功能|場景|場景大綱|假設|假如|當|那麼|而且|但是)\s*[:：]?') {
                    $lintIssues += [ordered]@{ file = $f; line = ($i + 1); issue = 'non_english_gherkin_keyword'; text = $ln.Trim() }
                }
                if ($ln -match '@Pending') {
                    $start = [Math]::Max(0, $i - 5)
                    $end = [Math]::Min($rawLines.Count - 1, $i + 5)
                    $window = ($rawLines[$start..$end] -join "`n")
                    if ($window -notmatch '#\s*TODO') {
                        $lintIssues += [ordered]@{ file = $f; line = ($i + 1); issue = 'pending_without_todo' }
                    }
                }
                if ($ln -match '^\s*(Given|When|Then|And|But)\s+(.+?)\s*$') {
                    $featureSteps += [pscustomobject]@{ file = $f; line = ($i + 1); text = $Matches[2] }
                }
            }
        }

        # Approximate binding check: cucumber-expression -> regex, match against @Given/@When/@Then.
        $stepPatterns = @()
        $stepJavaFiles = @(Get-ChildItem $StepDir -Recurse -Filter '*.java' -File -ErrorAction SilentlyContinue)
        foreach ($jf in $stepJavaFiles) {
            $jraw = Get-Content $jf.FullName -Raw -Encoding UTF8
            $annMatches = [regex]::Matches($jraw, '@(Given|When|Then)\s*\(\s*"((?:[^"\\]|\\.)*)"')
            foreach ($m in $annMatches) {
                $expr = $m.Groups[2].Value -replace '\\"', '"' -replace '\\\\', '\'
                if ($expr.StartsWith('^')) {
                    $rx = $expr
                } else {
                    $rx = [regex]::Escape($expr)
                    $rx = $rx -replace '\\\{string\}', '"[^"]*"'
                    $rx = $rx -replace '\\\{int\}', '-?\d+'
                    $rx = $rx -replace '\\\{float\}', '-?\d+(\.\d+)?'
                    $rx = $rx -replace '\\\{word\}', '\S+'
                    $rx = $rx -replace '\\\{\w*}', '.+'
                    $rx = "^$rx$"
                }
                $stepPatterns += $rx
            }
        }
        $unbound = @()
        foreach ($fs in ($featureSteps | Sort-Object -Property text -Unique)) {
            $matched = $false
            foreach ($rx in $stepPatterns) {
                try { if ($fs.text -match $rx) { $matched = $true; break } } catch {}
            }
            if (-not $matched) { $unbound += $fs }
        }

        $compile = [ordered]@{ status = 'skipped'; exit_code = $null; output_tail = @() }
        if (-not $SkipCompile) {
            $mvnCmd = Get-Command mvn -ErrorAction SilentlyContinue
            if ($null -eq $mvnCmd) {
                $compile.status = 'tool_missing'
            } else {
                $out = @(cmd /c "mvn -B -q test-compile 2>&1")
                $compile.exit_code = $LASTEXITCODE
                if ($LASTEXITCODE -eq 0) {
                    $compile.status = 'passed'
                } else {
                    $compile.status = 'failed'
                    $compile.output_tail = @($out | Select-Object -Last 40)
                }
            }
        }

        $dryRun = [ordered]@{ status = 'skipped'; exit_code = $null; undefined = @(); output_tail = @() }
        if ($Tag -and $compile.status -eq 'passed') {
            $out = @(cmd /c "mvn -B test -Dcucumber.filter.tags=@$Tag -Dcucumber.execution.dry-run=true 2>&1")
            $dryRun.exit_code = $LASTEXITCODE
            $dryRun.undefined = @($out | Where-Object { $_ -match 'undefined|UndefinedStep' } | Select-Object -First 10)
            if ($LASTEXITCODE -eq 0) {
                $dryRun.status = 'passed'
            } else {
                $dryRun.status = 'failed'
                $dryRun.output_tail = @($out | Select-Object -Last 40)
            }
        }

        $ok = ($lintIssues.Count -eq 0) -and ($unbound.Count -eq 0) -and
              ($compile.status -ne 'failed') -and ($dryRun.status -ne 'failed')
        Out-Json ([ordered]@{
                ok             = [bool]$ok
                lint           = $lintIssues
                binding        = [ordered]@{
                    step_patterns_found = $stepPatterns.Count
                    unbound_steps       = $unbound
                    note                = 'approximate match; custom parameter types may false-positive'
                }
                compile        = $compile
                dry_run        = $dryRun
            })
        break
    }

    'answer-add' {
        if (-not $Text) { Fail 'answer-add requires -Text' }
        $reqId = ''
        if ($null -ne (Get-ActivePlanFile)) { $reqId = (Read-Plan).plan.requirement_id }
        $ansDir = Split-Path $AnswersPath -Parent
        if ($ansDir -and -not (Test-Path $ansDir)) { New-Item -ItemType Directory -Force -Path $ansDir | Out-Null }
        if (-not (Test-Path $AnswersPath)) {
            $header = "# Feasibility Answers（前置能力問答累積）`r`n`r`n> 由 AC 可行性關口與 BP-P2 補件互動自動累積。P4 可行性預審會查閱此檔，命中的前置問題不再重問使用者。`r`n"
            Set-Content -Path $AnswersPath -Value $header -Encoding UTF8
        }
        $tagPart = ''
        if ($Id) { $tagPart = "[$Id] " }
        Add-Content -Path $AnswersPath -Value "- [$((Get-Date).ToString('yyyy-MM-dd'))] [$reqId] $tagPart$Text" -Encoding UTF8
        Out-Json ([ordered]@{ ok = $true; path = $AnswersPath })
        break
    }
}
