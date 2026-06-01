using Autodesk.AutoCAD.ApplicationServices.Core;
using Autodesk.AutoCAD.DatabaseServices;
using Autodesk.AutoCAD.EditorInput;
using Autodesk.AutoCAD.Geometry;
using Autodesk.AutoCAD.Runtime;
using SpePlugin.Servicos;
using System.Text.Json;

namespace SpePlugin.Comandos
{
    /// <summary>
    /// SPETOTAL — Importação rápida: coleta elementos + posições em memória e importa tudo no final.
    /// Fluxo: nome → qtde → área → nome → qtde → área → ENTER → resumo → confirma → importa tudo.
    /// </summary>
    public class ComandoTotal
    {
        /// <summary>
        /// Dados de um elemento coletado (em memória, antes de gravar).
        /// </summary>
        private class ElementoColetado
        {
            public string Nome { get; set; } = "";
            public int Quantidade { get; set; } = 1;
            public List<ExtratorTexto.PosicaoParseada> Posicoes { get; set; } = new();
            public List<ObjectId> ObjectIdsPosicoes { get; set; } = new();
            public List<string> Equivalentes { get; set; } = new();
            public ObjectId ObjectIdNome { get; set; }
            public Point3d Pt1 { get; set; }
            public Point3d Pt2 { get; set; }
        }

        [CommandMethod("SPETOTAL")]
        public void Executar()
        {
            var doc = Application.DocumentManager.MdiActiveDocument;
            var ed = doc.Editor;

            ed.WriteMessage("\n======================================");
            ed.WriteMessage("\n   SPETOTAL - Importacao Rapida       ");
            ed.WriteMessage("\n======================================\n");

            // 1. Carregar dados de referência
            SupabaseClient? client = null;
            try
            {
                client = new SupabaseClient();
                if (!SessaoAtual.DadosCarregados)
                {
                    ed.WriteMessage("\nCarregando dados do Supabase...");
                    SessaoAtual.Bitolas = client.ListarBitolas();
                    SessaoAtual.Formas = client.ListarFormas();
                    SessaoAtual.DadosCarregados = true;
                    ed.WriteMessage($" [OK]\n");
                }

                // Configurações sempre recarregam
                var configs = client.ListarConfiguracoesCad();
                if (configs.ContainsKey("plugin_cad_cor_importacao"))
                    SessaoAtual.CorImportacao = int.TryParse(configs["plugin_cad_cor_importacao"], out var cor) ? cor : 3;
                if (configs.ContainsKey("plugin_cad_marcar_x"))
                    SessaoAtual.MarcarComX = configs["plugin_cad_marcar_x"] == "true";
            }
            catch (System.Exception ex)
            {
                ed.WriteMessage($"\n[ERRO] Falha ao conectar: {ex.Message}\n");
                return;
            }

            // 2. Buscar detalhamento
            string detalhamentoId;
            string nomeDetalhamento;

            while (true)
            {
                var opCodigo = new PromptIntegerOptions("\nCodigo do detalhamento: ");
                opCodigo.AllowNegative = false;
                opCodigo.AllowZero = false;
                var resCodigo = ed.GetInteger(opCodigo);
                if (resCodigo.Status != PromptStatus.OK)
                {
                    ed.WriteMessage("\n[CANCELADO]\n");
                    return;
                }

                var codigo = resCodigo.Value;
                ed.WriteMessage($"\n  Buscando detalhamento #{codigo}...");
                try
                {
                    var resultados = client!.BuscarDetalhamentos(codigo.ToString());
                    if (resultados.Count == 0)
                    {
                        ed.WriteMessage($"\n  [!] Detalhamento #{codigo} nao encontrado.");
                        continue;
                    }

                    var escolhido = resultados[0];
                    nomeDetalhamento = $"#{Str(escolhido, "codigo")} - {Str(escolhido, "cliente_nome")} / {Str(escolhido, "obra_nome")}";

                    var opConf = new PromptKeywordOptions(
                        $"\n  {nomeDetalhamento}. Correto? [Sim/Nao]: ", "Sim Nao");
                    opConf.Keywords.Default = "Sim";
                    var resConf = ed.GetKeywords(opConf);
                    if (resConf.Status != PromptStatus.OK || resConf.StringResult == "Nao") continue;

                    detalhamentoId = Str(escolhido, "id");
                    ed.WriteMessage($"\n[OK] Detalhamento: {nomeDetalhamento}\n");
                    break;
                }
                catch (System.Exception ex)
                {
                    ed.WriteMessage($"\n  [ERRO] {ex.Message}\n");
                    continue;
                }
            }

            // Resolver forma padrão "1"
            string formaPadraoId = "";
            string formaPadraoCodigo = "1";
            var formaEncontrada = SessaoAtual.EncontrarForma("1");
            if (formaEncontrada != null)
            {
                formaPadraoId = formaEncontrada.Value.id;
                formaPadraoCodigo = formaEncontrada.Value.codigo;
            }

            // ══════════════════════════════════════════════════════
            // LOOP: Coleta elementos + posições em memória
            // ══════════════════════════════════════════════════════
            var elementosColetados = new List<ElementoColetado>();

            ed.WriteMessage("\n--------------------------------------");
            ed.WriteMessage("\n  Clique no nome de cada elemento,");
            ed.WriteMessage("\n  informe a quantidade, arraste a area.");
            ed.WriteMessage("\n  ENTER = finalizar coleta e importar.");
            ed.WriteMessage("\n  ESC = cancelar tudo.");
            ed.WriteMessage("\n--------------------------------------\n");

            while (true)
            {
                // ─── Clicar no nome do elemento ───
                var opEnt = new PromptEntityOptions($"\n  Clique no nome do elemento (ENTER = importar): ");
                opEnt.SetRejectMessage("\n  [!] Selecione TEXT ou MTEXT.");
                opEnt.AddAllowedClass(typeof(DBText), true);
                opEnt.AddAllowedClass(typeof(MText), true);
                opEnt.AllowNone = true;

                var resEnt = ed.GetEntity(opEnt);

                if (resEnt.Status == PromptStatus.Cancel)
                {
                    if (PerguntarCancelarOuRefazer(ed)) return;
                    continue;
                }

                if (resEnt.Status == PromptStatus.None)
                {
                    // ENTER vazio → fim da coleta
                    break;
                }

                if (resEnt.Status != PromptStatus.OK) break;

                // Extrair texto do elemento
                string nomeElemento = "";
                ObjectId nomeObjId = resEnt.ObjectId;
                using (var tr = doc.TransactionManager.StartTransaction())
                {
                    var ent = tr.GetObject(resEnt.ObjectId, OpenMode.ForRead);
                    if (ent is DBText dbText) nomeElemento = dbText.TextString;
                    else if (ent is MText mText) nomeElemento = mText.Text;
                    tr.Commit();
                }

                if (string.IsNullOrWhiteSpace(nomeElemento))
                {
                    ed.WriteMessage("\n  [!] Texto vazio, tente outro.\n");
                    continue;
                }

                nomeElemento = nomeElemento.Trim().ToUpper();

                // Parsear equivalentes: V101=V102 ou V101, V102, V103
                var equivalentes = new List<string>();
                var separadores = new[] { '=', ',' };
                if (nomeElemento.IndexOfAny(separadores) >= 0)
                {
                    var partes = nomeElemento.Split(separadores, System.StringSplitOptions.RemoveEmptyEntries);
                    nomeElemento = partes[0].Trim();
                    for (int p = 1; p < partes.Length; p++)
                    {
                        var equiv = partes[p].Trim();
                        if (!string.IsNullOrEmpty(equiv)) equivalentes.Add(equiv);
                    }
                }

                if (equivalentes.Count > 0)
                    ed.WriteMessage($"\n  Elemento: {nomeElemento} = {string.Join(" = ", equivalentes)}");
                else
                    ed.WriteMessage($"\n  Elemento: {nomeElemento}");

                // ─── Arrastar sobre o elemento (quantidade padrão 1, Q para alterar) ───
                int quantidade = 1;

                var opPt1 = new PromptPointOptions($"\n  Arraste sobre {nomeElemento} ou 'Q' para quantidade: ");
                opPt1.Keywords.Add("Quantidade", "Quantidade", "Quantidade(Q)");
                opPt1.AllowNone = false;

                PromptPointResult resPt1;
                while (true)
                {
                    resPt1 = ed.GetPoint(opPt1);
                    if (resPt1.Status == PromptStatus.Keyword && resPt1.StringResult == "Quantidade")
                    {
                        var opQtd = new PromptIntegerOptions($"\n  Quantidade de {nomeElemento} [1]: ");
                        opQtd.DefaultValue = 1;
                        opQtd.LowerLimit = 1;
                        opQtd.UpperLimit = 999;
                        var resQtd = ed.GetInteger(opQtd);
                        quantidade = resQtd.Status == PromptStatus.OK ? resQtd.Value : 1;
                        ed.WriteMessage($"\n  Quantidade: {quantidade}\n");
                        continue;
                    }
                    break;
                }

                if (resPt1.Status == PromptStatus.Cancel)
                {
                    if (PerguntarCancelarOuRefazer(ed)) return;
                    continue;
                }
                if (resPt1.Status != PromptStatus.OK)
                {
                    ed.WriteMessage("\n  [!] Ponto invalido, pulando elemento.\n");
                    continue;
                }

                var opPt2 = new PromptCornerOptions("\n  Segundo canto: ", resPt1.Value);
                var resPt2 = ed.GetCorner(opPt2);
                if (resPt2.Status == PromptStatus.Cancel)
                {
                    if (PerguntarCancelarOuRefazer(ed)) return;
                    continue;
                }
                if (resPt2.Status != PromptStatus.OK)
                {
                    ed.WriteMessage("\n  [!] Ponto invalido, pulando elemento.\n");
                    continue;
                }

                var filtro = new SelectionFilter(new[]
                {
                    new TypedValue((int)DxfCode.Operator, "<OR"),
                    new TypedValue((int)DxfCode.Start, "TEXT"),
                    new TypedValue((int)DxfCode.Start, "MTEXT"),
                    new TypedValue((int)DxfCode.Operator, "OR>"),
                });

                var resSel = ed.SelectCrossingWindow(resPt1.Value, resPt2.Value, filtro);

                if (resSel.Status != PromptStatus.OK || resSel.Value.Count == 0)
                {
                    ed.WriteMessage("  [!] Nenhum texto na area, pulando elemento.\n");
                    continue;
                }

                // Parsear posições
                var posicoes = new List<ExtratorTexto.PosicaoParseada>();
                var objectIds = new List<ObjectId>();

                using (var tr = doc.TransactionManager.StartTransaction())
                {
                    foreach (SelectedObject selObj in resSel.Value)
                    {
                        var ent = tr.GetObject(selObj.ObjectId, OpenMode.ForRead);
                        string txt = "";
                        if (ent is DBText dbText) txt = dbText.TextString;
                        else if (ent is MText mText) txt = mText.Text;
                        if (string.IsNullOrWhiteSpace(txt)) continue;

                        var parsed = ExtratorTexto.TentarParsearPosicao(txt.Trim());
                        if (parsed != null)
                        {
                            posicoes.Add(parsed);
                            objectIds.Add(selObj.ObjectId);
                        }
                    }
                    tr.Commit();
                }

                if (posicoes.Count == 0)
                {
                    ed.WriteMessage("  [!] Nenhuma posicao encontrada na area, pulando elemento.\n");
                    continue;
                }

                // Validar bitolas
                int bitolasNaoEncontradas = 0;
                foreach (var p in posicoes)
                {
                    if (SessaoAtual.EncontrarBitola(p.BitolaMm) == null)
                        bitolasNaoEncontradas++;
                }

                // Ordenar por número da posição
                posicoes = posicoes.OrderBy(p => p.NumeroPosicao).ToList();

                var nomesPosicoes = string.Join(", ", posicoes.Select(p => $"N{p.NumeroPosicao}"));
                ed.WriteMessage($"\n  [✓] {nomeElemento} ({quantidade}x): {posicoes.Count} posicoes ({nomesPosicoes})");

                if (bitolasNaoEncontradas > 0)
                    ed.WriteMessage($"\n      [!] {bitolasNaoEncontradas} bitola(s) nao cadastrada(s)");

                ed.WriteMessage("\n");

                elementosColetados.Add(new ElementoColetado
                {
                    Nome = nomeElemento,
                    Quantidade = quantidade,
                    Posicoes = posicoes,
                    ObjectIdsPosicoes = objectIds,
                    ObjectIdNome = nomeObjId,
                    Equivalentes = equivalentes,
                    Pt1 = resPt1.Value,
                    Pt2 = resPt2.Value,
                });

                // ─── Marcar X + cor imediatamente ───
                try
                {
                    using (var trMark = doc.TransactionManager.StartTransaction())
                    {
                        var btr = (BlockTableRecord)trMark.GetObject(
                            doc.Database.CurrentSpaceId, OpenMode.ForWrite);
                        int corIdx = SessaoAtual.CorImportacao;

                        // Marcar nome do elemento
                        var entNome = trMark.GetObject(nomeObjId, OpenMode.ForWrite) as Entity;
                        if (entNome != null)
                            entNome.ColorIndex = (short)corIdx;

                        // Marcar textos das posições
                        foreach (var objId in objectIds)
                        {
                            var ent = trMark.GetObject(objId, OpenMode.ForWrite) as Entity;
                            if (ent != null)
                                ent.ColorIndex = (short)corIdx;
                        }

                        // Marcar X na área
                        if (SessaoAtual.MarcarComX)
                        {
                            var p1 = resPt1.Value;
                            var p2 = resPt2.Value;

                            var linha1 = new Line(
                                new Point3d(p1.X, p1.Y, 0),
                                new Point3d(p2.X, p2.Y, 0));
                            linha1.ColorIndex = (short)corIdx;
                            var linha2 = new Line(
                                new Point3d(p1.X, p2.Y, 0),
                                new Point3d(p2.X, p1.Y, 0));
                            linha2.ColorIndex = (short)corIdx;
                            btr.AppendEntity(linha1);
                            trMark.AddNewlyCreatedDBObject(linha1, true);
                            btr.AppendEntity(linha2);
                            trMark.AddNewlyCreatedDBObject(linha2, true);
                        }

                        trMark.Commit();
                    }
                }
                catch (System.Exception exMark)
                {
                    ed.WriteMessage($"\n  [!] Nao marcou: {exMark.Message}");
                }
            }

            // ══════════════════════════════════════════════════════
            // RESUMO + CONFIRMAÇÃO
            // ══════════════════════════════════════════════════════
            if (elementosColetados.Count == 0)
            {
                ed.WriteMessage("\n[!] Nenhum elemento coletado.\n");
                return;
            }

            int totalPos = elementosColetados.Sum(e => e.Posicoes.Count);

            ed.WriteMessage("\n======================================");
            ed.WriteMessage("\n  SPETOTAL — Resumo da importacao");
            ed.WriteMessage("\n======================================\n");

            foreach (var elem in elementosColetados)
            {
                var nomes = string.Join(", ", elem.Posicoes.Select(p => $"N{p.NumeroPosicao}"));
                ed.WriteMessage($"\n  {elem.Nome} ({elem.Quantidade}x): {elem.Posicoes.Count} posicoes ({nomes})");
            }

            ed.WriteMessage($"\n\n  Total: {elementosColetados.Count} elementos, {totalPos} posicoes");
            ed.WriteMessage($"\n  Forma padrao: {formaPadraoCodigo}");
            ed.WriteMessage($"\n  Comprimentos: (vazio — preencher no app)\n");

            var opFinal = new PromptKeywordOptions("\n  Confirmar importacao? [Sim/Nao]: ", "Sim Nao");
            opFinal.Keywords.Default = "Sim";
            var resFinal = ed.GetKeywords(opFinal);

            if (resFinal.Status != PromptStatus.OK || resFinal.StringResult == "Nao")
            {
                ed.WriteMessage("\n[CANCELADO] Nenhum dado foi gravado.\n");
                return;
            }

            // ══════════════════════════════════════════════════════
            // IMPORTAÇÃO — tudo de uma vez
            // ══════════════════════════════════════════════════════
            ed.WriteMessage("\n  Importando...\n");
            int elemSalvos = 0;
            int posSalvas = 0;

            try
            {
                int elemTotal = elementosColetados.Count;
                int elemAtual = 0;

                foreach (var elem in elementosColetados)
                {
                    elemAtual++;
                    // POST elemento
                    var elemMap = new Dictionary<string, object?>
                    {
                        ["nome"] = elem.Nome,
                        ["quantidade"] = elem.Quantidade,
                        ["peso_total"] = 0,
                        ["detalhamento_id"] = detalhamentoId,
                        ["elementos_equivalentes"] = elem.Equivalentes,
                    };

                    ed.WriteMessage($"\n  [{elemAtual}/{elemTotal}] {elem.Nome}...");
                    var elementoId = client!.CriarElemento(elemMap);

                    if (string.IsNullOrEmpty(elementoId))
                    {
                        ed.WriteMessage(" [ERRO] Sem ID!");
                        continue;
                    }

                    ed.WriteMessage(" elemento criado.");

                    // POST posições
                    int posCount = 0;
                    foreach (var p in elem.Posicoes)
                    {
                        var bitola = SessaoAtual.EncontrarBitola(p.BitolaMm);

                        var posicao = new Modelos.Posicao
                        {
                            NumeroPosicao = p.NumeroPosicao,
                            Quantidade = p.Quantidade,
                            BitolaMm = p.BitolaMm,
                            BitolaId = bitola?.id ?? "",
                            BitolaNome = bitola?.nome ?? $"o{p.BitolaMm}",
                            FormaCodigo = formaPadraoCodigo,
                            FormaId = formaPadraoId,
                            Comprimentos = new Dictionary<string, int>(),
                        };

                        var posMap = posicao.ToSupabaseMap(elementoId);
                        posMap.Remove("id");
                        client.CriarPosicao(posMap);
                        posCount++;
                        ed.WriteMessage($" N{p.NumeroPosicao}");
                    }

                    elemSalvos++;
                    posSalvas += posCount;
                    ed.WriteMessage($" — {posCount} pos [OK]");
                }

                // Tocar detalhamento para Realtime
                client!.TocarDetalhamento(detalhamentoId);
            }
            catch (System.Exception ex)
            {
                ed.WriteMessage($"\n\n  [ERRO] {ex.Message}");
                if (ex.InnerException != null)
                    ed.WriteMessage($"\n    Inner: {ex.InnerException.Message}");
                ed.WriteMessage("\n");
            }

            // ══════════════════════════════════════════════════════
            // RESUMO FINAL
            // ══════════════════════════════════════════════════════
            ed.WriteMessage("\n======================================");
            ed.WriteMessage($"\n  Detalhamento: {nomeDetalhamento}");
            ed.WriteMessage($"\n  {elemSalvos} elementos, {posSalvas} posicoes");
            ed.WriteMessage("\n  Dados ja estao no app Flutter!");
            ed.WriteMessage("\n======================================\n");
        }

        private static string Str(Dictionary<string, object?> dict, string key)
        {
            if (!dict.TryGetValue(key, out var val)) return "";
            if (val is JsonElement je) return je.ToString();
            return val?.ToString() ?? "";
        }

        /// <summary>
        /// Pergunta ao usuário se quer cancelar a importação ou refazer o último elemento.
        /// Retorna true = cancelar tudo, false = refazer.
        /// </summary>
        private bool PerguntarCancelarOuRefazer(Editor ed)
        {
            var op = new PromptKeywordOptions(
                "\n  Cancelar importacao ou refazer? [Cancelar/Refazer]: ", "Cancelar Refazer");
            op.Keywords.Default = "Refazer";
            op.AllowNone = true;

            var res = ed.GetKeywords(op);
            if (res.Status == PromptStatus.OK && res.StringResult == "Cancelar")
            {
                ed.WriteMessage("\n[CANCELADO] Nenhum dado foi gravado.\n");
                return true;
            }
            ed.WriteMessage("\n  Refazendo...\n");
            return false;
        }
    }
}
