param([switch]$Watch)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$project = Join-Path $root 'projeto_micro.uvprojx'
$sourceDir = Join-Path $root 'src'
$groupName = 'Source Group 1'

function Sync-KeilProject {
    if (-not (Test-Path -LiteralPath $project)) { throw "Projeto nao encontrado: $project" }
    if (-not (Test-Path -LiteralPath $sourceDir)) { return }

    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($project)
    $target = $xml.SelectSingleNode("/Project/Targets/Target[TargetName='Target_1']")
    if ($null -eq $target) { throw 'Target_1 nao encontrado.' }
    $group = $target.SelectSingleNode("Groups/Group[GroupName='$groupName']")
    if ($null -eq $group) { throw "Grupo '$groupName' nao encontrado." }

    $present = @{}
    foreach ($fileNode in $target.SelectNodes('Groups/Group/Files/File')) {
        $pathNode = $fileNode.SelectSingleNode('FilePath')
        if ($null -eq $pathNode -or [string]::IsNullOrWhiteSpace($pathNode.InnerText)) { continue }
        $relative = $pathNode.InnerText.Replace('/', '\')
        $full = [IO.Path]::GetFullPath((Join-Path $root $relative)).ToLowerInvariant()
        $present[$full] = $true
    }

    $newFiles = @(Get-ChildItem -LiteralPath $sourceDir -File -Recurse |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.c', '.s', '.asm') } |
        Sort-Object FullName |
        Where-Object { -not $present.ContainsKey($_.FullName.ToLowerInvariant()) })
    if ($newFiles.Count -eq 0) { return }

    $filesNode = $group.SelectSingleNode('Files')
    if ($null -eq $filesNode) {
        $filesNode = $xml.CreateElement('Files')
        [void]$group.AppendChild($filesNode)
    }

    foreach ($file in $newFiles) {
        $relative = $file.FullName.Substring($root.TrimEnd('\').Length + 1).Replace('/', '\')
        $fileNode = $xml.CreateElement('File')
        foreach ($pair in @(
            @('FileName', $file.Name),
            @('FileType', $(if ($file.Extension.ToLowerInvariant() -eq '.c') { '1' } else { '2' })),
            @('FilePath', ".\$relative")
        )) {
            $element = $xml.CreateElement($pair[0])
            $element.InnerText = [string]$pair[1]
            [void]$fileNode.AppendChild($element)
        }
        [void]$filesNode.AppendChild($fileNode)
        Write-Host "Adicionado: $relative"
    }

    # Salva primeiro em arquivo temporario e valida antes de substituir.
    $temp = "$project.tmp"
    $writer = $null
    try {
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
        $settings.Indent = $false
        $writer = [System.Xml.XmlWriter]::Create($temp, $settings)
        $xml.Save($writer)
        $writer.Dispose(); $writer = $null
        $check = New-Object System.Xml.XmlDocument
        $check.Load($temp)
        if ($null -eq $check.SelectSingleNode('/Project/Targets/Target/Groups/Group/Files/File')) {
            throw 'Validacao falhou: nenhum arquivo foi gravado no XML.'
        }
        $safetyBackup = "$project.original.bak"
        if (-not (Test-Path -LiteralPath $safetyBackup)) {
            Copy-Item -LiteralPath $project -Destination $safetyBackup
        }
        Copy-Item -LiteralPath $temp -Destination $project -Force
        Write-Host 'Sincronizacao concluida. Reabra o projeto no Keil para atualizar a arvore.'
    }
    finally {
        if ($null -ne $writer) { $writer.Dispose() }
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

if ($Watch) {
    Write-Host 'Monitorando src/ a cada 2 segundos; Ctrl+C para encerrar.'
    while ($true) {
        try { Sync-KeilProject } catch { Write-Warning $_.Exception.Message }
        Start-Sleep -Seconds 2
    }
} else {
    Sync-KeilProject
}
