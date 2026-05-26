using System.Text.RegularExpressions;
using System.Globalization;

namespace SpePlugin.Servicos
{
    /// <summary>
    /// Extrai dados de texto de entidades AutoCAD.
    /// Reutiliza as mesmas regex do parser DXF do app Flutter.
    /// </summary>
    public static class ExtratorTexto
    {
        // Regex para posição completa:
        //   "2 N35 ø12.5 C=415"      → Qtd=2, Pos=35, Bitola=12.5, C=415
        //   "2x3 N9 ø6.3 C=corr"     → Qtd=6, Pos=9, Bitola=6.3, C=0
        //   "1 N26 ø10.0 C=501"       → Qtd=1, Pos=26, Bitola=10.0, C=501
        //
        // Grupo 1: quantidade (pode ter multiplicação: "2x3", "4x2")
        // Grupo 2: número da posição
        // Grupo 3: bitola
        // Grupo 4: comprimento (número ou texto como "corr")
        private static readonly Regex _rePosicao = new(
            @"([\d]+(?:\s*[xX×]\s*[\d]+)*)\s*N(\d+)\s*[øØφ∅](\d+[.,]?\d*)\s*C\s*=\s*(\S+)",
            RegexOptions.Compiled);

        // Regex para rótulo de elemento: "V101", "P1", "L1", etc.
        private static readonly Regex _reElemento = new(
            @"^[VPLEBSC]\d+",
            RegexOptions.Compiled | RegexOptions.IgnoreCase);

        /// <summary>
        /// Resultado do parse de um texto de posição de armadura.
        /// </summary>
        public class PosicaoParseada
        {
            public int Quantidade { get; set; }
            public int NumeroPosicao { get; set; }
            public double BitolaMm { get; set; }
            public int Comprimento { get; set; }
        }

        /// <summary>
        /// Tenta parsear um texto como posição de armadura.
        /// Exemplo: "2 N35 ø12.5 C=415" → Qtd=2, Pos=35, Bitola=12.5, C=415
        /// Exemplo: "2x3 N9 ø6.3 C=corr" → Qtd=6, Pos=9, Bitola=6.3, C=0
        /// </summary>
        public static PosicaoParseada? TentarParsearPosicao(string texto)
        {
            var match = _rePosicao.Match(texto.Trim());
            if (!match.Success) return null;

            // Parsear quantidade com multiplicação (ex: "2x3" = 6, "4" = 4)
            var qtdTexto = match.Groups[1].Value;
            int quantidade = ParsearQuantidade(qtdTexto);

            // Parsear comprimento (número ou texto como "corr", "var", etc.)
            int comprimento = 0;
            var compTexto = match.Groups[4].Value;
            int.TryParse(compTexto, out comprimento);

            return new PosicaoParseada
            {
                Quantidade = quantidade,
                NumeroPosicao = int.Parse(match.Groups[2].Value),
                BitolaMm = double.Parse(match.Groups[3].Value.Replace(',', '.'), CultureInfo.InvariantCulture),
                Comprimento = comprimento,
            };
        }

        /// <summary>
        /// Parseia quantidade com multiplicação.
        /// "2x3" → 6, "4X2" → 8, "5" → 5
        /// </summary>
        private static int ParsearQuantidade(string texto)
        {
            var partes = Regex.Split(texto.Trim(), @"\s*[xX×]\s*");
            int resultado = 1;
            foreach (var parte in partes)
            {
                if (int.TryParse(parte.Trim(), out int val))
                    resultado *= val;
            }
            return resultado;
        }

        /// <summary>
        /// Verifica se um texto é rótulo de elemento (V101, P1, L1, etc.).
        /// </summary>
        public static bool EhRotuloElemento(string texto)
        {
            var trimmed = texto.Trim();
            var match = _reElemento.Match(trimmed);
            return match.Success && match.Value == trimmed;
        }

        /// <summary>
        /// Extrai o nome do elemento de um rótulo.
        /// </summary>
        public static string? ExtrairNomeElemento(string texto)
        {
            var trimmed = texto.Trim();
            var match = _reElemento.Match(trimmed);
            if (match.Success && match.Value == trimmed)
                return match.Value.ToUpper();
            return null;
        }
    }
}
