namespace SpePlugin.Modelos
{
    /// <summary>
    /// Detalhamento — agrupa elementos de um projeto estrutural.
    /// Espelha a tabela 'detalhamentos' do Supabase.
    /// </summary>
    public class Detalhamento
    {
        public string? Id { get; set; }
        public string ClienteId { get; set; } = "";
        public string ClienteNome { get; set; } = "";
        public string ObraId { get; set; } = "";
        public string ObraNome { get; set; } = "";
        public double PesoTotal { get; set; } = 0;
        public List<Elemento> Elementos { get; set; } = new();

        /// <summary>
        /// Converte para o formato JSON aceito pela REST API do Supabase.
        /// </summary>
        public Dictionary<string, object?> ToSupabaseMap()
        {
            var map = new Dictionary<string, object?>
            {
                ["cliente_id"] = ClienteId,
                ["cliente_nome"] = ClienteNome,
                ["obra_id"] = ObraId,
                ["obra_nome"] = ObraNome,
                ["peso_total"] = PesoTotal,
            };
            if (!string.IsNullOrEmpty(Id) && Id.Length == 36)
                map["id"] = Id;
            return map;
        }

        public int TotalElementos => Elementos.Count;
        public int TotalPosicoes => Elementos.Sum(e => e.Posicoes.Count);

        public override string ToString() =>
            $"Detalhamento: {ClienteNome} / {ObraNome} — {TotalElementos} elementos, {TotalPosicoes} posições";
    }
}
