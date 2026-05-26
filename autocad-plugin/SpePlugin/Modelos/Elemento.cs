namespace SpePlugin.Modelos
{
    /// <summary>
    /// Elemento estrutural (V101, P1, L1, etc.).
    /// Espelha a tabela 'elementos' do Supabase.
    /// </summary>
    public class Elemento
    {
        public string? Id { get; set; }
        public string Nome { get; set; } = "";
        public int Quantidade { get; set; } = 1;
        public double PesoTotal { get; set; } = 0;
        public List<string> ElementosEquivalentes { get; set; } = new();
        public List<Posicao> Posicoes { get; set; } = new();

        /// <summary>
        /// Converte para o formato JSON aceito pela REST API do Supabase.
        /// </summary>
        public Dictionary<string, object?> ToSupabaseMap(string detalhamentoId)
        {
            var map = new Dictionary<string, object?>
            {
                ["nome"] = Nome,
                ["quantidade"] = Quantidade,
                ["peso_total"] = PesoTotal,
                ["detalhamento_id"] = detalhamentoId,
                ["elementos_equivalentes"] = ElementosEquivalentes,
            };
            if (!string.IsNullOrEmpty(Id) && Id.Length == 36)
                map["id"] = Id;
            return map;
        }

        public override string ToString()
        {
            var equiv = ElementosEquivalentes.Count > 0
                ? $" (equiv: {string.Join(", ", ElementosEquivalentes)})"
                : "";
            return $"  {Nome} — qtd: {Quantidade}{equiv} — {Posicoes.Count} posições";
        }
    }
}
