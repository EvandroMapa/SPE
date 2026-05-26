# Padrão de Importação de Projetos Estruturais (PDF → JSON)

## Contexto
O sistema Acoplan importa projetos estruturais de diversas fontes (Eberick, TQS, manuais, etc).
A IA analisa o PDF e gera um JSON com os elementos (vigas, pilares, lajes) e suas posições (barras de aço).

## Estrutura do JSON Esperado

```json
{
  "elementos": [
    {
      "nome": "V101",
      "quantidade": 1,
      "equivalentes": [],
      "posicoes": [
        {
          "posicao": "35",
          "quantidade": 2,
          "bitola_mm": 12.5,
          "forma_codigo": "Reta",
          "comprimentos": null
        }
      ]
    }
  ]
}
```

## Regras Críticas de Parsing

### 1. SEÇÃO é a Fonte de Verdade
- A **SEÇÃO transversal** (SEÇÃO A-A, B-B, etc.) é a fonte autoritativa para:
  - **Quantidade total** de cada posição
  - **Tipo** (estribo vs barra longitudinal)
  - **Bitola** (diâmetro)
  - **Comprimento de corte** (C=)
- Exemplo: `64 N1 ø5.0 C=111` na seção → posição 1, 64 unidades, ø5.0mm, comprimento 111cm

### 2. Distribuição ao Longo da Viga ≠ Quantidade
- A notação `15 N1 c/17.5` ao longo da elevação da viga significa:
  - 15 estribos da posição 1, espaçados a cada 17.5cm
  - **NÃO** criar uma entrada com quantidade 15
- O total é a SOMA das distribuições: `15 + 23 + 26 = 64` (deve bater com a seção)
- `c/XX` = espaçamento centro a centro, não é relevante para o JSON

### 3. Comprimento de Corte (C=)
- Sempre capturar o valor de `C=` (ex: C=415 → comprimento 415cm)
- Se `C= < soma das medidas parciais` → é comprimento de corte
- Se `C= = soma das medidas parciais` → é comprimento total
- Armazenar no campo `comprimentos` ou equivalente

### 4. Posições em Múltiplas Vistas
- A mesma posição pode aparecer em diferentes vistas (elevação, seção, detalhe)
- **NÃO duplicar** — é a mesma barra vista de ângulos diferentes
- Usar a seção como referência para quantidade total

### 5. Notação 2c, 3c (cantos/dobras)
- `(2c)` = 2 cantos/dobras na barra
- **Ignorar** para fins de importação — não é relevante para o sistema
- A forma é definida pelo `forma_codigo` (Reta, Estribo, Pele, etc.)

### 6. Separação de Elementos
- Cada viga (V101, V102...), pilar (P1, P2...) ou laje (L1, L2...) é um elemento separado
- **NUNCA misturar posições de elementos diferentes**
- As posições são locais ao elemento — posição 1 da V101 ≠ posição 1 da V102

### 7. Formas (forma_codigo)
- **Estribo**: barras fechadas/semi-fechadas que envolvem a seção (aparecem na seção transversal como contorno)
- **Reta**: barras longitudinais retas
- **Pele**: barras de armadura de pele (laterais, para controle de fissuração)
- Identificar pelo contexto no desenho (posição na seção, orientação, notação)

### 8. Equivalentes
- Alguns elementos são idênticos em geometria e armadura
- Indicados no projeto como "V101 = V105" ou similar
- Mapear no campo `equivalentes: ["V105"]`

## Exemplo Correto — V101 (Viga de Fundação)

Dado o desenho:
- Elevação: `2 N35 ø12.5 C=415`, distribuição `12N12c/5 | 15 N1 c/17.5 | 23 N1 c/17.5 | 26 N1 c/17.5`
- Detalhe inferior: `2 N29 ø12.5 C=73 (2c)`, `2 N30 ø12.5 C=77`
- Seção A-A: `64 N1 ø5.0 C=111`, `12 N12 ø8.0 C=112`

JSON correto:
```json
{
  "nome": "V101",
  "quantidade": 1,
  "equivalentes": [],
  "posicoes": [
    {"posicao": "35", "quantidade": 2, "bitola_mm": 12.5, "forma_codigo": "Reta", "comprimento": 415},
    {"posicao": "29", "quantidade": 2, "bitola_mm": 12.5, "forma_codigo": "Reta", "comprimento": 73},
    {"posicao": "30", "quantidade": 2, "bitola_mm": 12.5, "forma_codigo": "Reta", "comprimento": 77},
    {"posicao": "1",  "quantidade": 64, "bitola_mm": 5.0,  "forma_codigo": "Estribo", "comprimento": 111},
    {"posicao": "12", "quantidade": 12, "bitola_mm": 8.0,  "forma_codigo": "Estribo", "comprimento": 112}
  ]
}
```

## Erros Comuns da IA a Evitar
1. ❌ Pegar quantidade da distribuição (`15 N1 c/17.5` → qty=15) ao invés do total da seção (64)
2. ❌ Misturar posições de elementos diferentes (posição de outra viga aparecendo na V101)
3. ❌ Classificar estribo como "Reta" ou vice-versa
4. ❌ Deixar comprimento null quando C= está disponível
5. ❌ Duplicar posição que aparece em múltiplas vistas
6. ❌ Criar posições fantasmas que não existem no desenho
