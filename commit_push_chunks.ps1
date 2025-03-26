###############################################################################
# Arquivo: commit_push_chunks.ps1
# Autor: Halyson © 2025
###############################################################################
# Tamanho máximo total por commit (2 GB)
$maxSize = 2147483648
# Limite para Git LFS para arquivos individuais (50 MB)
$lfsThreshold = 49904512

# (Opcional) Configura a página de código para UTF‑8
chcp 65001 | Out-Null

###############################################################################
# Função para decodificar uma string contendo sequências octais (ex: "\344\271\214")
# Ela percorre a string e, quando encontra uma barra invertida seguida de 3 dígitos,
# converte essa sequência para o byte correspondente. Os demais caracteres são 
# convertidos usando UTF‑8.
function Decode-OctalPath {
    param (
        [string]$rawPath
    )
    $bytes = New-Object System.Collections.Generic.List[byte]
    $i = 0
    while ($i -lt $rawPath.Length) {
        if ($rawPath[$i] -eq '\' -and ($i + 3) -lt $rawPath.Length -and 
            ($rawPath[$i+1] -match '\d') -and ($rawPath[$i+2] -match '\d') -and ($rawPath[$i+3] -match '\d')) {
            # Captura os 3 dígitos seguintes
            $oct = $rawPath.Substring($i+1, 3)
            try {
                $byte = [convert]::ToByte($oct, 8)
                $bytes.Add($byte)
            }
            catch {
                # Se der erro, adiciona os bytes da sequência original
                $charBytes = [System.Text.Encoding]::UTF8.GetBytes($rawPath.Substring($i,4))
                $bytes.AddRange($charBytes)
            }
            $i += 4
        }
        else {
            # Adiciona o byte correspondente ao caractere atual (usando UTF-8)
            $charBytes = [System.Text.Encoding]::UTF8.GetBytes($rawPath[$i])
            $bytes.AddRange($charBytes)
            $i++
        }
    }
    return [System.Text.Encoding]::UTF8.GetString($bytes.ToArray())
}

###############################################################################
# 0) Verifica commits locais não enviados (push)
###############################################################################
Write-Host "Verificando commits locais não enviados..."
$unpushedCommits = git log origin/main..HEAD
if ($unpushedCommits) {
    Write-Host "Foram encontrados commits locais não enviados. Enviando..."
    git push
} else {
    Write-Host "Nenhum commit não enviado encontrado."
}

###############################################################################
# 1) Coleta arquivos alterados, adicionados e não rastreados pelo Git
###############################################################################
Write-Host "Executando 'git status --porcelain -uall' para encontrar arquivos alterados, adicionados ou não rastreados..."
$gitStatusOutput = git status --porcelain -uall
if (-not $gitStatusOutput) {
    Write-Host "Nenhum arquivo alterado, adicionado ou não rastreado encontrado para commit."
    exit
}
$gitStatusLines = $gitStatusOutput -split "`r?`n" | Where-Object { $_ -ne "" }
if ($gitStatusLines.Count -eq 0) {
    Write-Host "Nenhum item encontrado para processar."
    exit
}

###############################################################################
# 2) Cria uma lista de arquivos e seus tamanhos a partir das linhas do status
###############################################################################
Write-Host "Processando as linhas do status do Git..."
$filesList = @()
foreach ($line in $gitStatusLines) {
    if ($line.Length -ge 3) {
        $rawPath = $line.Substring(3).Trim()
        if ($rawPath.StartsWith('"') -and $rawPath.EndsWith('"')) {
            $rawPath = $rawPath.Substring(1, $rawPath.Length - 2)
        }
        $decodedPath = Decode-OctalPath $rawPath

        #Write-Host "Raw: $rawPath"
        #Write-Host "Decodificado: $decodedPath"

        if (Test-Path $decodedPath -PathType Leaf) {
            $size = (Get-Item $decodedPath).Length
            $filesList += [PSCustomObject]@{
                FilePath = $decodedPath
                Size     = $size
            }
        }
        elseif (Test-Path $decodedPath -PathType Container) {
            Write-Host "Expandindo diretório: $decodedPath"
            $subFiles = Get-ChildItem $decodedPath -Recurse -File
            foreach ($f in $subFiles) {
                $filesList += [PSCustomObject]@{
                    FilePath = $f.FullName
                    Size     = $f.Length
                }
            }
        }
        else {
            Write-Host "ATENÇÃO: Caminho '$decodedPath' não foi encontrado."
        }
    }
}
if ($filesList.Count -eq 0) {
    Write-Host "Nenhum arquivo válido encontrado para processar."
    exit
}
Write-Host "Foram encontrados $($filesList.Count) arquivo(s) para processar."

###############################################################################
# 3) Lógica de batching e Git LFS
###############################################################################
$batch = @()
$currentBatchSize = 0
$commitCount = 1
function Commit-Batch {
    param (
        [array]$BatchFiles,
        [int]$CommitNumber,
        [int]$BatchSize
    )
    $chunkSize = 200
    $totalFiles = $BatchFiles.Count
    Write-Host "Adicionando $totalFiles arquivos ao commit $CommitNumber em chunks de $chunkSize..."
    for ($i = 0; $i -lt $totalFiles; $i += $chunkSize) {
        $end = [math]::Min($i + $chunkSize - 1, $totalFiles - 1)
        $subBatch = $BatchFiles[$i..$end]
        Write-Host "  Adicionando arquivos $($i+1) a $($end+1)..."
        git add -- $subBatch
    }
    Write-Host "Realizando commit do batch $CommitNumber (tamanho total: $BatchSize bytes)..."
    git commit -m "Batch commit $CommitNumber"
    git push
}
Write-Host "Iniciando o processo de commit..."
foreach ($item in $filesList) {
    $filePath = $item.FilePath
    $size     = $item.Size
    if ($size -ge $lfsThreshold) {
        Write-Host "Arquivo '$filePath' possui >= 99MB. Adicionando ao Git LFS..."
        git lfs track "$filePath" | Out-Null
        git add .gitattributes
        git add "$filePath"
        git commit -m "Commit de arquivo grande '$filePath' via Git LFS"
        git push
        continue
    }
    if (($currentBatchSize + $size) -gt $maxSize -and $batch.Count -gt 0) {
        Commit-Batch -BatchFiles $batch -CommitNumber $commitCount -BatchSize $currentBatchSize
        $commitCount++
        $batch = @()
        $currentBatchSize = 0
    }
    if ($size -gt $maxSize -and $batch.Count -eq 0) {
        Write-Host "Arquivo '$filePath' excede 2GB sozinho. Comitando separadamente."
        git add "$filePath"
        git commit -m "Batch commit $commitCount (arquivo único grande)"
        git push
        $commitCount++
        continue
    }
    $batch += $filePath
    $currentBatchSize += $size
}
if ($batch.Count -gt 0) {
    Commit-Batch -BatchFiles $batch -CommitNumber $commitCount -BatchSize $currentBatchSize
}
Write-Host "Todos os arquivos alterados, adicionados ou não rastreados foram processados, comitados e enviados."
