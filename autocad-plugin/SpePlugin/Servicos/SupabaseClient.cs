using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace SpePlugin.Servicos
{
    /// <summary>
    /// Cliente HTTP SÍNCRONO para a REST API do Supabase.
    /// Usa chamadas síncronas para evitar deadlock na thread STA do AutoCAD.
    /// Todas as requisições usam o token do usuário logado (AuthService):
    /// o banco só aceita usuários autenticados.
    /// </summary>
    public class SupabaseClient
    {
        private readonly HttpClient _http;

        public SupabaseClient()
        {
            _http = new HttpClient();
            _http.DefaultRequestHeaders.Add("apikey", ConfigService.SupabaseKey);
            _http.DefaultRequestHeaders.Add("Prefer", "return=representation");
            // Garante o login já na criação do cliente (abre a janela se preciso)
            AuthService.ObterToken();
            _http.Timeout = TimeSpan.FromSeconds(15);
        }

        private string BaseUrl => $"{ConfigService.SupabaseUrl}/rest/v1";

        // ══════════════════════════════════════════════════════
        // LEITURA
        // ══════════════════════════════════════════════════════

        public List<Dictionary<string, object?>> ListarClientes()
        {
            return Get("clientes?select=*");
        }

        public List<Dictionary<string, object?>> ListarBitolas()
        {
            return Get("bitolas?select=*&order=sort_index");
        }

        public List<Dictionary<string, object?>> ListarFormas()
        {
            return Get("formas?select=*");
        }

        public Dictionary<string, string> ListarConfiguracoesCad()
        {
            var result = new Dictionary<string, string>();
            try
            {
                var rows = Get("configuracoes?select=chave,valor&chave=in.(plugin_cad_cor_importacao,plugin_cad_marcar_x)");
                foreach (var r in rows)
                {
                    var chave = r.ContainsKey("chave") ? r["chave"]?.ToString() ?? "" : "";
                    var valor = r.ContainsKey("valor") ? r["valor"]?.ToString() ?? "" : "";
                    if (!string.IsNullOrEmpty(chave))
                        result[chave] = valor;
                }
            }
            catch { }
            return result;
        }

        // ══════════════════════════════════════════════════════
        // ESCRITA
        // ══════════════════════════════════════════════════════

        public string CriarDetalhamento(Dictionary<string, object?> dados)
        {
            var resultado = Post("detalhamentos", dados);
            return resultado?["id"]?.ToString() ?? "";
        }

        public string CriarElemento(Dictionary<string, object?> dados)
        {
            var resultado = Post("elementos", dados);
            return resultado?["id"]?.ToString() ?? "";
        }

        public string CriarPosicao(Dictionary<string, object?> dados)
        {
            var resultado = Post("posicoes", dados);
            return resultado?["id"]?.ToString() ?? "";
        }

        public void AtualizarPosicao(string posicaoId, Dictionary<string, object?> dados)
        {
            Patch($"posicoes?id=eq.{posicaoId}", dados);
        }

        public void ExcluirPosicao(string posicaoId)
        {
            Delete($"posicoes?id=eq.{posicaoId}");
        }

        public void ExcluirPosicoesPorElemento(string elementoId)
        {
            Delete($"posicoes?elemento_id=eq.{elementoId}");
        }

        public void ExcluirElemento(string elementoId)
        {
            Delete($"elementos?id=eq.{elementoId}");
        }

        public int ProximoCodigo()
        {
            try
            {
                var result = Get("detalhamentos?select=codigo&order=codigo.desc&limit=1");
                if (result.Count > 0 && result[0].TryGetValue("codigo", out var cod))
                {
                    if (cod is JsonElement je && je.TryGetInt32(out int val))
                        return val + 1;
                }
            }
            catch { }
            return 1;
        }

        /// <summary>
        /// Busca detalhamentos por código (número) ou nome do cliente/obra.
        /// </summary>
        public List<Dictionary<string, object?>> BuscarDetalhamentos(string termo)
        {
            // Se é número, buscar por código exato
            if (int.TryParse(termo, out int codigo))
            {
                return Get($"detalhamentos?select=id,codigo,cliente_nome,obra_nome&codigo=eq.{codigo}&limit=10");
            }

            // Senão, buscar por nome do cliente OU nome da obra (case insensitive)
            var termoEncoded = Uri.EscapeDataString($"%{termo}%");
            return Get($"detalhamentos?select=id,codigo,cliente_nome,obra_nome&or=(cliente_nome.ilike.{termoEncoded},obra_nome.ilike.{termoEncoded})&order=codigo.desc&limit=10");
        }

        /// <summary>
        /// Não faz mais nada: o app escuta o Realtime de elementos e posições
        /// diretamente. Antes gravava um valor negativo em peso_total só para
        /// disparar o Realtime, deixando o peso do detalhamento errado no banco.
        /// Mantido para não alterar os comandos que o chamam.
        /// </summary>
        public void TocarDetalhamento(string detalhamentoId)
        {
        }

        // ══════════════════════════════════════════════════════
        // HTTP Helpers — 100% SÍNCRONO (evita deadlock no AutoCAD)
        // ══════════════════════════════════════════════════════

        /// <summary>
        /// Envia a requisição com o token do usuário. Se o token expirou (401),
        /// renova e tenta uma vez mais. Erros do banco (ex: elemento em pedido
        /// técnico aberto) viram exceção com a mensagem do servidor.
        /// </summary>
        private string Enviar(HttpMethod metodo, string endpoint, string? corpoJson = null)
        {
            for (int tentativa = 0; ; tentativa++)
            {
                var request = new HttpRequestMessage(metodo, $"{BaseUrl}/{endpoint}");
                request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", AuthService.ObterToken());
                if (corpoJson != null)
                    request.Content = new StringContent(corpoJson, Encoding.UTF8, "application/json");

                var response = _http.SendAsync(request).GetAwaiter().GetResult();
                var resposta = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();

                if ((int)response.StatusCode == 401 && tentativa == 0)
                {
                    AuthService.Invalidar();
                    continue;
                }
                if (!response.IsSuccessStatusCode)
                    throw new HttpRequestException(MensagemErro(resposta, response.ReasonPhrase));
                return resposta;
            }
        }

        private static string MensagemErro(string resposta, string? padrao)
        {
            try
            {
                using var doc = JsonDocument.Parse(resposta);
                if (doc.RootElement.TryGetProperty("message", out var m))
                    return m.GetString() ?? padrao ?? "Erro";
            }
            catch { }
            return padrao ?? "Erro";
        }

        private List<Dictionary<string, object?>> Get(string endpoint)
        {
            return DeserializeList(Enviar(HttpMethod.Get, endpoint));
        }

        private Dictionary<string, object?>? Post(string endpoint, Dictionary<string, object?> dados)
        {
            var lista = DeserializeList(Enviar(HttpMethod.Post, endpoint, JsonSerializer.Serialize(dados)));
            return lista.Count > 0 ? lista[0] : null;
        }

        private void Patch(string endpoint, Dictionary<string, object?> dados)
        {
            Enviar(new HttpMethod("PATCH"), endpoint, JsonSerializer.Serialize(dados));
        }

        private void Delete(string endpoint)
        {
            Enviar(HttpMethod.Delete, endpoint);
        }

        private static List<Dictionary<string, object?>> DeserializeList(string json)
        {
            var result = new List<Dictionary<string, object?>>();
            using var doc = JsonDocument.Parse(json);

            JsonElement root;
            if (doc.RootElement.ValueKind == JsonValueKind.Array)
                root = doc.RootElement;
            else
                return result;

            foreach (var item in root.EnumerateArray())
            {
                var dict = new Dictionary<string, object?>();
                foreach (var prop in item.EnumerateObject())
                {
                    dict[prop.Name] = prop.Value.Clone();
                }
                result.Add(dict);
            }
            return result;
        }
    }
}
