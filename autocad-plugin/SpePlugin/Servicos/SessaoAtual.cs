namespace SpePlugin.Servicos
{
    /// <summary>
    /// Armazena os dados coletados durante a sessão de trabalho.
    /// Os dados ficam em memória até o envio ao Supabase.
    /// </summary>
    public static class SessaoAtual
    {
        public static Modelos.Detalhamento? Detalhamento { get; set; }
        public static Modelos.Elemento? ElementoAtivo { get; set; }

        // Dados de referência carregados do Supabase
        public static List<Dictionary<string, object?>> Clientes { get; set; } = new();
        public static List<Dictionary<string, object?>> Bitolas { get; set; } = new();
        public static List<Dictionary<string, object?>> Formas { get; set; } = new();
        public static bool DadosCarregados { get; set; } = false;

        // Configurações do plugin CAD
        public static int CorImportacao { get; set; } = 3; // verde padrão
        public static bool MarcarComX { get; set; } = true;

        /// <summary>
        /// Limpa toda a sessão.
        /// </summary>
        public static void Limpar()
        {
            Detalhamento = null;
            ElementoAtivo = null;
        }

        /// <summary>
        /// Verifica se existe um detalhamento ativo.
        /// </summary>
        public static bool TemDetalhamento => Detalhamento != null;

        /// <summary>
        /// Verifica se existe um elemento ativo.
        /// </summary>
        public static bool TemElementoAtivo => ElementoAtivo != null;

        /// <summary>
        /// Encontra a bitola pelo diâmetro em mm (ex: 12.5 para ø12,5mm).
        /// </summary>
        public static (string id, string nome)? EncontrarBitola(double bitolaMm)
        {
            foreach (var prod in Bitolas)
            {
                if (prod.TryGetValue("diametro", out var diam))
                {
                    double diamValor = 0;
                    if (diam is System.Text.Json.JsonElement je)
                        diamValor = je.GetDouble();
                    else if (diam is double d)
                        diamValor = d;
                    else if (double.TryParse(diam?.ToString() ?? "",
                        System.Globalization.NumberStyles.Any,
                        System.Globalization.CultureInfo.InvariantCulture, out double parsed))
                        diamValor = parsed;

                    if (Math.Abs(diamValor - bitolaMm) < 0.1)
                    {
                        var id = prod["id"]?.ToString() ?? "";
                        var nome = prod["nome"]?.ToString() ?? "";
                        return (id, nome);
                    }
                }
            }
            return null;
        }

        /// <summary>
        /// Encontra a forma pelo código (Reta, L, U, etc.).
        /// </summary>
        public static (string id, string codigo)? EncontrarForma(string formaCodigo)
        {
            foreach (var forma in Formas)
            {
                if (forma.TryGetValue("codigo", out var cod))
                {
                    var codigo = cod?.ToString() ?? "";
                    if (string.Equals(codigo, formaCodigo, StringComparison.OrdinalIgnoreCase))
                    {
                        var id = forma["id"]?.ToString() ?? "";
                        return (id, codigo);
                    }
                }
            }
            return null;
        }
    }
}
