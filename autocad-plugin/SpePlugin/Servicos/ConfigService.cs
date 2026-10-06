using System.IO;
using System.Text.Json;

namespace SpePlugin.Servicos
{
    /// <summary>
    /// Gerencia configuração do plugin (URL e Key do Supabase).
    /// Salva em arquivo local na pasta do usuário.
    /// </summary>
    public static class ConfigService
    {
        private static readonly string _configPath = System.IO.Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
            "SpePlugin",
            "config.json"
        );

        public static string SupabaseUrl { get; set; } = "https://kyatsdowjljkhivvdvzo.supabase.co";
        /// <summary>Refresh token do login (a senha nunca é gravada).</summary>
        public static string RefreshToken { get; set; } = "";

        /// <summary>Último e-mail usado no login (preenche a janela de login).</summary>
        public static string Email { get; set; } = "";

        public static string SupabaseKey { get; set; } = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5YXRzZG93amxqa2hpdnZkdnpvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5NzIyODcsImV4cCI6MjA5MjU0ODI4N30.l21LY_n5zwn-vt8mi0KpxCXN7PYplR7pI-G589InwY0";

        /// <summary>
        /// Carrega configuração do disco, ou usa valores padrão.
        /// </summary>
        public static void Carregar()
        {
            try
            {
                if (System.IO.File.Exists(_configPath))
                {
                    var json = System.IO.File.ReadAllText(_configPath);
                    var config = JsonSerializer.Deserialize<Dictionary<string, string>>(json);
                    if (config != null)
                    {
                        if (config.TryGetValue("url", out var url)) SupabaseUrl = url;
                        if (config.TryGetValue("key", out var key)) SupabaseKey = key;
                        if (config.TryGetValue("refresh_token", out var rt)) RefreshToken = rt;
                        if (config.TryGetValue("email", out var em)) Email = em;
                    }
                }
            }
            catch
            {
                // Usa valores padrão se der erro
            }
        }

        /// <summary>
        /// Salva configuração atual no disco.
        /// </summary>
        public static void Salvar()
        {
            try
            {
                var dir = System.IO.Path.GetDirectoryName(_configPath)!;
                System.IO.Directory.CreateDirectory(dir);

                var config = new Dictionary<string, string>
                {
                    ["url"] = SupabaseUrl,
                    ["key"] = SupabaseKey,
                    ["refresh_token"] = RefreshToken,
                    ["email"] = Email,
                };
                var json = JsonSerializer.Serialize(config, new JsonSerializerOptions { WriteIndented = true });
                System.IO.File.WriteAllText(_configPath, json);
            }
            catch
            {
                // Silencioso
            }
        }
    }
}
