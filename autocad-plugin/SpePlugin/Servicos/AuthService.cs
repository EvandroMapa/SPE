using System.Net.Http;
using System.Text;
using System.Text.Json;

namespace SpePlugin.Servicos
{
    /// <summary>
    /// Login do plugin no Supabase Auth (mesmo usuário e senha do app SPE).
    /// A senha nunca é gravada: só o refresh token fica salvo no config.json,
    /// e o access token é renovado automaticamente quando expira.
    /// </summary>
    public static class AuthService
    {
        private static readonly HttpClient _http = new HttpClient { Timeout = TimeSpan.FromSeconds(15) };

        private static string? _accessToken;
        private static DateTime _expiraEmUtc = DateTime.MinValue;

        public static bool Autenticado => !string.IsNullOrEmpty(_accessToken) || !string.IsNullOrEmpty(ConfigService.RefreshToken);

        public static string EmailAtual => ConfigService.Email;

        /// <summary>
        /// Retorna um access token válido. Renova pelo refresh token salvo ou,
        /// se não houver, abre a janela de login.
        /// </summary>
        public static string ObterToken()
        {
            if (!string.IsNullOrEmpty(_accessToken) && DateTime.UtcNow < _expiraEmUtc.AddSeconds(-60))
                return _accessToken!;

            if (!string.IsNullOrEmpty(ConfigService.RefreshToken))
            {
                try
                {
                    Autenticar("refresh_token", new Dictionary<string, string> { ["refresh_token"] = ConfigService.RefreshToken });
                    return _accessToken!;
                }
                catch
                {
                    // Refresh token expirado/revogado: pede login de novo
                    ConfigService.RefreshToken = "";
                    ConfigService.Salvar();
                }
            }

            if (!PedirLogin())
                throw new InvalidOperationException("Login cancelado. Use SPE_LOGIN para entrar.");
            return _accessToken!;
        }

        /// <summary>Descarta o access token atual (ex: após resposta 401).</summary>
        public static void Invalidar()
        {
            _accessToken = null;
            _expiraEmUtc = DateTime.MinValue;
        }

        /// <summary>Abre a janela de login. Retorna false se o usuário cancelar.</summary>
        public static bool PedirLogin()
        {
            string? erro = null;
            while (true)
            {
                var credenciais = LoginDialog.Mostrar(ConfigService.Email, erro);
                if (credenciais == null) return false;
                try
                {
                    Autenticar("password", new Dictionary<string, string>
                    {
                        ["email"] = credenciais.Value.Email.Trim().ToLowerInvariant(),
                        ["password"] = credenciais.Value.Senha,
                    });
                    return true;
                }
                catch (Exception ex)
                {
                    erro = ex.Message;
                }
            }
        }

        public static void Sair()
        {
            Invalidar();
            ConfigService.RefreshToken = "";
            ConfigService.Salvar();
        }

        private static void Autenticar(string grantType, Dictionary<string, string> corpo)
        {
            var url = $"{ConfigService.SupabaseUrl}/auth/v1/token?grant_type={grantType}";
            var request = new HttpRequestMessage(HttpMethod.Post, url);
            request.Headers.Add("apikey", ConfigService.SupabaseKey);
            request.Content = new StringContent(JsonSerializer.Serialize(corpo), Encoding.UTF8, "application/json");

            var response = _http.SendAsync(request).GetAwaiter().GetResult();
            var json = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            if (!response.IsSuccessStatusCode)
            {
                var codigo = root.TryGetProperty("error_code", out var c) ? c.GetString() : null;
                if (codigo == "invalid_credentials" || (int)response.StatusCode == 400)
                    throw new InvalidOperationException("Usuário ou senha inválidos.");
                var msg = root.TryGetProperty("msg", out var m) ? m.GetString()
                        : root.TryGetProperty("error_description", out var d) ? d.GetString()
                        : response.ReasonPhrase;
                throw new InvalidOperationException($"Falha no login: {msg}");
            }

            _accessToken = root.GetProperty("access_token").GetString();
            var expiraEm = root.TryGetProperty("expires_in", out var e) ? e.GetInt32() : 3600;
            _expiraEmUtc = DateTime.UtcNow.AddSeconds(expiraEm);

            ConfigService.RefreshToken = root.GetProperty("refresh_token").GetString() ?? "";
            if (root.TryGetProperty("user", out var user) && user.TryGetProperty("email", out var email))
                ConfigService.Email = email.GetString() ?? ConfigService.Email;
            ConfigService.Salvar();
        }
    }
}
