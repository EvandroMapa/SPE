namespace SpePlugin.Modelos
{
    /// <summary>
    /// Posição de armadura (ex: N35, ø12.5, Reta, C=415).
    /// Espelha a tabela 'posicoes' do Supabase.
    /// </summary>
    public class Posicao
    {
        public string? Id { get; set; }
        public int NumeroPosicao { get; set; }
        public int Quantidade { get; set; } = 1;
        public string BitolaId { get; set; } = "";
        public string BitolaNome { get; set; } = "";
        public double BitolaMm { get; set; } = 0;
        public string FormaId { get; set; } = "";
        public string FormaCodigo { get; set; } = "";
        public Dictionary<string, int> Comprimentos { get; set; } = new();
        public int Multiplicador { get; set; } = 1;
        public int ComprimentoDeCorte { get; set; } = 0;

        /// <summary>
        /// Converte para o formato JSON aceito pela REST API do Supabase.
        /// </summary>
        public Dictionary<string, object?> ToSupabaseMap(string elementoId)
        {
            var map = new Dictionary<string, object?>
            {
                ["posicao"] = NumeroPosicao,
                ["qtde"] = Quantidade,
                ["bitola_id"] = !string.IsNullOrEmpty(BitolaId) ? BitolaId : null,
                ["bitola_nome"] = BitolaNome,
                ["forma_id"] = !string.IsNullOrEmpty(FormaId) ? FormaId : null,
                ["forma_codigo"] = FormaCodigo,
                ["comprimentos"] = Comprimentos,
                ["variaveis"] = new Dictionary<string, bool>(),
                ["variaveis_config"] = new Dictionary<string, object>(),
                ["multiplicador"] = Multiplicador,
                ["elemento_id"] = elementoId,
                ["comprimento_de_corte"] = ComprimentoDeCorte,
            };
            if (!string.IsNullOrEmpty(Id) && Id.Length == 36)
                map["id"] = Id;
            return map;
        }

        public override string ToString() =>
            $"    N{NumeroPosicao} — {Quantidade}x ø{BitolaMm}mm {FormaCodigo} C={ComprimentoString}";

        private string ComprimentoString =>
            Comprimentos.Count > 0
                ? string.Join(", ", Comprimentos.Select(kv => $"{kv.Key}={kv.Value}"))
                : "—";
    }
}
