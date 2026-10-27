param([switch]$Watch)

$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$project = Join-Path $root 'projeto_micro.uvprojx'
$sourceDir = Join-Path $root 'src'
$targetName = 'Target_1'
$managedPrefix = 'src - '

function Sync-KeilProject {
    if (-not (Test-Path -LiteralPath $project)) { throw "Projeto nao encontrado: $project" }
    if (-not (Test-Path -LiteralPath $sourceDir)) { return }

    $xml = New-Object System.Xml.XmlDocument
    $xml.PreserveWhitespace = $true
    $xml.Load($project)
    $target = $xml.SelectSingleNode("/Project/Targets/Target[TargetName='$targetName']")
    if ($null -eq $target) { throw "Target nao encontrado: $targetName" }
    $groups = $target.SelectSingleNode('Groups')
    if ($null -eq $groups) { throw 'Elemento Groups ausente.' }

    # Evita que um mesmo arquivo seja registrado em dois grupos.
    $present = @{}
    foreach ($node in $target.SelectNodes('Groups/Group/Files/File')) {
        $p = $node.SelectSingleNode('FilePath')
        if ($null -eq $p -or [string]::IsNullOrWhiteSpace($p.InnerText)) { continue }
        try {
            $full = [IO.Path]::GetFullPath((Join-Path $root $p.InnerText.Replace('/', '\')))
            $present[$full.ToLowerInvariant()] = $true
        } catch { Write-Warning "Caminho ignorado no projeto: $($p.InnerText)" }
    }

    $candidates = @(Get-ChildItem -LiteralPath $sourceDir -File -Recurse |
        Where-Object { $_.Extension.ToLowerInvariant() -in @('.c', '.s', '.asm') } |
        Sort-Object FullName |
        Where-Object { -not $present.ContainsKey($_.FullName.ToLowerInvariant()) })
    if ($candidates.Count -eq 0) { return }

    foreach ($file in $candidates) {
        $folderRelative = $file.DirectoryName.Substring($sourceDir.TrimEnd('\').Length).TrimStart('\','/')
        $groupName = if ([string]::IsNullOrEmpty($folderRelative)) { 'src - raiz' } else { $managedPrefix + $folderRelative.Replace('/', '\') }

        $group = $null
        foreach ($g in $groups.SelectNodes('Group')) {
            $gn = $g.SelectSingleNode('GroupName')
            if ($null -ne $gn -and $gn.InnerText -eq $groupName) { $group = $g; break }
        }
        if ($null -eq $group) {
            $group = $xml.CreateElement('Group')
            $name = $xml.CreateElement('GroupName')
            $name.InnerText = $groupName
            [void]$group.AppendChild($name)
            [void]$groups.AppendChild($group)
        }
        $filesNode = $group.SelectSingleNode('Files')
        if ($null -eq $filesNode) {
            $filesNode = $xml.CreateElement('Files')
            [void]$group.AppendChild($filesNode)
        }

        $relative = $file.FullName.Substring($root.TrimEnd('\').Length + 1).Replace('/', '\')
        $fileNode = $xml.CreateElement('File')
        foreach ($item in @(
            @('FileName', $file.Name),
            @('FileType', $(if ($file.Extension.ToLowerInvariant() -eq '.c') { '1' } else { '2' })),
            @('FilePath', ".\$relative")
        )) {
            $child = $xml.CreateElement([string]$item[0])
            $child.InnerText = [string]$item[1]
            [void]$fileNode.AppendChild($child)
        }
        [void]$filesNode.AppendChild($fileNode)
        Write-Host "Adicionado: $relative -> $groupName"
    }

    # Backup imutavel da primeira sincronizacao, antes de alterar o arquivo.
    $backup = "$project.original.bak"
    if (-not (Test-Path -LiteralPath $backup)) { Copy-Item -LiteralPath $project -Destination $backup }

    # Escrita em arquivo temporario, com XML validado antes de substituir o original.
    $temp = "$project.tmp"
    $writer = $null
    try {
        $settings = New-Object System.Xml.XmlWriterSettings
        $settings.Encoding = [System.Text.UTF8Encoding]::new($false)
        $settings.Indent = $false
        $settings.CloseOutput = $true
        $writer = [System.Xml.XmlWriter]::Create($temp, $settings)
        $xml.Save($writer)
        $writer.Dispose(); $writer = $null
        $check = New-Object System.Xml.XmlDocument
        $check.Load($temp)
        if ($null -eq $check.SelectSingleNode("/Project/Targets/Target[TargetName='$targetName']/Groups")) {
            throw 'XML gerado sem a estrutura de grupos esperada.'
        }
        Copy-Item -LiteralPath $temp -Destination $project -Force
        Write-Host 'Arquivo .uvprojx atualizado. Reabra o projeto no Keil para atualizar a arvore.'
    }
    finally {
        if ($null -ne $writer) { $writer.Dispose() }
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

if ($Watch) {
    Write-Host 'Monitorando src/ a cada 2 segundos. Para encerrar: Tasks: Terminate Task.'
    while ($true) {
        try { Sync-KeilProject } catch { Write-Warning $_.Exception.Message }
        Start-Sleep -Seconds 2
    }
} else {
    Sync-KeilProject
}
