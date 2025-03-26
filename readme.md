# Commit Push Chunks

Este script em PowerShell foi desenvolvido para auxiliar no gerenciamento de commits e no push de arquivos em repositórios Git que possuem grande quantidade de arquivos ou arquivos de tamanho elevado. Ele é especialmente útil para repositórios que precisam dividir os commits em “batches” (lotes) para evitar que um único commit ultrapasse limites (por exemplo, 2 GB por commit) e também para tratar automaticamente arquivos grandes com Git LFS.

## Recursos

- **Push de Commits Locais:**  
  Verifica e envia (push) automaticamente commits locais que ainda não foram enviados para o repositório remoto.

- **Coleta de Arquivos Alterados, Adicionados e Não Rastreado:**  
  Utiliza `git status --porcelain -uall` para identificar todos os arquivos modificados, adicionados (staged) e não rastreados.

- **Decodificação de Caminhos com Sequências Octais:**  
  Alguns repositórios podem apresentar nomes de arquivos com sequências octais (por exemplo, `\345\217\221`) para representar caracteres especiais (como caracteres chineses).  
  O script contém uma função personalizada, `Decode-OctalPath`, que percorre o caminho “raw” e converte cada sequência do tipo `\ddd` para o caractere correspondente utilizando a codificação UTF‑8.

- **Batching de Arquivos:**  
  Os arquivos são agrupados em batches para que o tamanho total de cada commit não ultrapasse 2 GB.  
  Se um arquivo individual exceder esse limite (e não for elegível para LFS), ele será commitado separadamente.

- **Integração com Git LFS:**  
  Arquivos com tamanho maior ou igual a 99 MB são automaticamente tratados pelo Git LFS. O script os processa individualmente, garantindo que o repositório não fique sobrecarregado com arquivos muito grandes.

- **Chunking para Git Add:**  
  Para evitar erros com o limite de tamanho da linha de comando, os arquivos de um batch são adicionados em “chunks” (por padrão, 200 arquivos por chunk).

## Pré-requisitos

- **Windows com PowerShell** (versão 5 ou superior é recomendada).  
- **Git** instalado e configurado no PATH.  
- **Git LFS** instalado e configurado.  
- Para correta exibição dos caracteres especiais (como os caracteres chineses), é recomendável:
  - Executar `chcp 65001` no PowerShell para definir a página de código para UTF‑8.
  - Utilizar uma fonte que suporte caracteres chineses (ex.: NSimSun ou SimSun).

## Como Usar

1. **Coloque o Script no Repositório:**  
   Salve o arquivo `commit_push_chunks.ps1` na raiz do seu repositório.

2. **Abra o PowerShell:**  
   Navegue até a raiz do repositório.

3. **Configure o Console (Opcional):**  
   Execute o comando abaixo para definir a página de código para UTF‑8:
   ```powershell
   chcp 65001
   ```
   Se necessário, ajuste a fonte do console para suportar caracteres chineses.

4. **Execute o Script:**  
   No PowerShell, execute:
   ```powershell
   .\commit_push_chunks.ps1
   ```

5. **Funcionamento do Script:**  
   - **Push Inicial:** O script verifica se há commits locais não enviados e os envia.
   - **Coleta e Decodificação:** Em seguida, ele coleta os arquivos modificados, adicionados e não rastreados, decodifica os caminhos com sequências octais e os transforma nos nomes reais dos arquivos.
   - **Batching e Git LFS:**  
     Os arquivos são agrupados em batches, sendo que arquivos com tamanho ≥ 99 MB são tratados automaticamente via Git LFS.  
     Cada batch é commitado e enviado (push) individualmente.
   - **Debug:**  
     O script exibe mensagens de debug mostrando o caminho “raw” e o caminho “decodificado” (além de uma representação hexadecimal) para ajudar na verificação da conversão.

## Funcionamento Interno

1. **Decodificação dos Caminhos:**  
   A função `Decode-OctalPath` percorre a string “raw” e, sempre que encontra uma sequência `\ddd`, converte os 3 dígitos para o byte correspondente e, ao final, decodifica o array de bytes usando UTF‑8.

2. **Verificação de Existência:**  
   Após a decodificação, o script utiliza `Test-Path` para verificar se o caminho existe (como arquivo ou diretório). Se for um diretório, todos os arquivos nele contidos são adicionados à lista de processamento.

3. **Batching e Push:**  
   Os arquivos são agrupados para que cada commit não ultrapasse 2 GB. Para cada batch, os arquivos são adicionados em chunks (para evitar erros de tamanho de linha de comando) e, em seguida, commitados e enviados ao repositório remoto.

## Avisos e Considerações

- **Exibição de Caracteres:**  
  Se os caracteres chineses não forem exibidos corretamente (aparecendo como “?”), verifique a configuração do console (página de código e fonte).

- **Test-Path:**  
  Mesmo que a exibição não seja perfeita, se os comandos Test-Path retornarem True, os arquivos estão sendo identificados corretamente.

- **Personalização:**  
  Você pode ajustar os limites (tamanho máximo por commit, limite para Git LFS, chunk size) conforme as necessidades do seu projeto.

## Licença

Este script é fornecido "no estado em que se encontra", sem garantias de qualquer tipo. Sinta-se à vontade para modificá-lo, adaptá-lo e distribuí-lo conforme necessário.

