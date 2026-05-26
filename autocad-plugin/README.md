# SPE Plugin para AutoCAD 2025

Plugin .NET que exporta detalhamentos de armadura do AutoCAD diretamente para o Supabase, onde o app Flutter SPE recebe em tempo real.

## Pré-requisitos

- AutoCAD 2025 (inglês ou português)
- .NET 8.0 SDK (instalado em `C:\dotnet`)

## Como compilar

```powershell
# Adicionar dotnet ao PATH (se necessário)
$env:Path += ";C:\dotnet"

# Compilar
cd d:\DESENVOLVIMENTO\SPE\autocad-plugin\SpePlugin
dotnet build -c Release
```

O arquivo `SpePlugin.dll` será gerado em `bin\Release\`.

## Como usar no AutoCAD

1. Abra o AutoCAD 2025
2. Digite `NETLOAD` na barra de comandos
3. Selecione o arquivo `SpePlugin.dll`
4. Pronto! Os comandos SPE estão disponíveis.

## Comandos

| Comando | Descrição |
|---------|-----------|
| `SPE_NOVO` | Cria novo detalhamento (carrega clientes/obras do Supabase) |
| `SPE_ELEM` | Adiciona elemento (V101, P1, L1...) |
| `SPE_POS` | Adiciona posição de armadura (por seleção de texto ou manual) |
| `SPE_ENVIAR` | Envia tudo para o Supabase |
| `SPE_STATUS` | Mostra dados coletados na sessão |
| `SPE_LIMPAR` | Limpa a sessão atual |

## Fluxo de uso

```
1. SPE_NOVO    → Escolhe cliente e obra
2. SPE_ELEM    → Digita "V101" (nome do elemento)
3. SPE_POS     → Clica no texto "2 N35 ø12.5 C=415"
                  (repete para cada armadura)
4. SPE_ELEM    → Digita "P1" (próximo elemento)
5. SPE_POS     → Clica nos textos de armadura do P1
6. SPE_ENVIAR  → Confirma e envia tudo ao Supabase
7. App Flutter → Detalhamento aparece automaticamente! 🎉
```

## Autoload (opcional)

Para carregar o plugin automaticamente ao abrir o AutoCAD, crie um arquivo `acad.lsp` na pasta de suporte do AutoCAD com:

```lisp
(command "NETLOAD" "D:\\DESENVOLVIMENTO\\SPE\\autocad-plugin\\SpePlugin\\bin\\Release\\SpePlugin.dll")
```

Ou use o comando `APPLOAD` no AutoCAD e adicione o .dll à lista de inicialização.
