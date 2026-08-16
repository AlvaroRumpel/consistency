# Consistency v2 — Design

Data: 2026-08-15. Estado atual: app Flutter Android-only, metas = strings dentro da última entrada diária, 1 blob JSON em SharedPreferences, sem streak, sem edição de dias passados, sem lembrete, sem backup.

## Objetivo

Transformar o app num habit tracker completo mantendo a identidade (botão grande "salvar hoje", visual atual como base): metas como entidades, consistência diária + streak, edição de hoje e últimos 7 dias, calendário/heatmap, lembrete inteligente, export/import, onboarding, i18n PT-BR/EN, widget Android. Migrar dados dos usuários já instalados sem perda.

## Decisões fechadas

| Tema | Decisão |
|---|---|
| Tipo de meta | Por meta: `check` (0/100) ou `percent` (slider 0–100, 5 passos) |
| Dia consistente | Média das metas ativas do dia ≥ threshold (setting, default 50, passo 5) |
| Streak | Regra B: dias anteriores sem registro quebram; hoje ainda não marcado não quebra. Global e por meta |
| Remover meta | Arquiva (soft delete). Restaurável. Histórico intacto |
| Renomear | Propaga (mesma entidade) |
| Editar | Hoje sempre editável (upsert). Passado: janela de 7 dias. Botão salvar explícito |
| Persistência | Arquivo JSON versionado em app docs dir; SharedPreferences só pra settings. Repositório abstrato pra futuro Firebase |
| Estado | `provider` (ChangeNotifier). `BaseController` só pra estado local de tela |
| Notificação | 1 lembrete diário, horário configurável, cancela se hoje já salvo |
| Telas | 3 tabs (Calendar, Home, Settings) + tela detalhe de meta (push). Sem FAB/PageView hack |
| Fora de escopo | iOS, CI (opcional no final), sync cloud, marcar direto no widget |

## Fases

Cada fase: spec já aqui, plano próprio (writing-plans), branch própria, app publicável ao fim.

| # | Fase | Depende | Entrega |
|---|---|---|---|
| 0 | Higiene | — | `.gitignore` build/, remover `.iml`/zip/PNGs raiz, pubspec description/version, `ThemeMode.system` default, remover `immersiveSticky`, splash espera `LocalData` em vez de 1500ms, tela de erro visível (texto + retry) nos 3 estados `*Error`, `beforeDelete` limpo após próximo save |
| 0-D | Design (paralelo à 0) | — | Projeto no claude-design MCP: todas as telas da Seção 3, light+dark, tokens (seed = `AppColors.primaryColor`). Aprovação por tela antes de qualquer fase de UI |
| 1 | Theme/M3 | 0, 0-D tokens | `ColorScheme.fromSeed`, `ThemeExtension` p/ text styles, apagar todo `isDark ? :` fora do ThemeData, `provider` no lugar de `ThemeProvider` custom |
| 2 | Núcleo de dados | 1 | Modelos, `GoalsRepository`/`FileGoalsRepository`, `SettingsRepository`, `AppStore`, migração v1→v2, testes. UI igual por fora |
| 3 | Engine | 2 | `ConsistencyEngine` puro + testes tabelados. Home mostra streak global e por meta; cor do botão via engine; threshold em settings |
| 4 | Edição livre + detalhe + nav | 3, 0-D | Tira trava de hoje, tipo de meta, arquivar/restaurar, tela detalhe de meta, nav bar M3 limpa, edição de dia ≤7d (usa calendário atual até fase 5) |
| 5 | Calendar/heatmap | 3, 0-D | Grid mensal próprio + heatmap anual; remove `flutter_calendar_carousel` |
| 6 | Notificações | 4 | Lembrete diário inteligente |
| 7 | Export/import + onboarding | 2, 4, 0-D | Share/import JSON, merge/replace; onboarding 1º uso |
| 8 | i18n | 4–7 | arb PT-BR/EN, todas strings extraídas |
| 9 | Widget Android | 3, 6, 0-D | `home_widget`: streak + estado de hoje, tap abre app |

## Seção 1 — Modelo de dados, repositório, migração

```dart
enum GoalType { check, percent }

class Goal {
  final String id;            // uuid v4
  final String name;
  final GoalType type;
  final DateTime createdAt;   // data sem hora; ativa a partir daqui
  final DateTime? archivedAt; // null = ativa
  final DateTime updatedAt;
}

class DayEntry {
  final DateTime date;               // 00:00 local
  final Map<String, double> values;  // goalId -> 0..100 (check = 0|100)
  final DateTime updatedAt;
}

class AppData {
  final int schemaVersion;           // 2
  final List<Goal> goals;
  final List<DayEntry> entries;      // ordenadas por date
}
```

Regras:
- Meta ativa no dia D: `createdAt ≤ D && (archivedAt == null || D < archivedAt)`.
- `values` só contém metas ativas no dia; ausente = 0.
- Datas serializadas `"yyyy-MM-dd"`; `updatedAt` ISO-8601 UTC.
- Salvar dia = upsert por `date`.
- `updatedAt` existe só pra merge (import, futuro sync). Não exibido.

```dart
abstract class GoalsRepository {
  Future<AppData> load();
  Future<void> save(AppData data);
}
```
- `FileGoalsRepository`: `<appDocs>/consistency.json`. Escrita: grava `.tmp`, renomeia; antes de renomear copia atual pra `.bak`. Leitura: se parse falha, tenta `.bak`.
- `SettingsRepository` (SharedPreferences): `nickname`, `themeMode` (system/light/dark), `threshold` (int 0–100, default 50), `notifEnabled` (bool, default false), `notifHour`/`notifMinute` (default 20:00), `onboardingDone` (bool).
- `AppStore extends ChangeNotifier`: guarda `AppData` em memória; mutações `addGoal`, `renameGoal`, `setGoalType`, `archiveGoal`, `restoreGoal`, `setValue(date, goalId, v)`, `saveDay(date)`, `replaceAll(AppData)`, `merge(AppData)`, `clearAll()` + `undoClear()`; cada mutação persistente chama `repo.save`. Substitui `LocalData` e `LocalData.revision`.
- `SettingsStore extends ChangeNotifier` sobre `SettingsRepository`. `ThemeModel` some (vira campo de `SettingsStore`).
- Providers no `main`: `MultiProvider([ChangeNotifierProvider(AppStore), ChangeNotifierProvider(SettingsStore)])`. Telas usam `context.watch/select`.

Migração v1→v2 (uma vez, no primeiro `load()` quando arquivo não existe e SharedPreferences tem `userData`):
1. Decodifica formato antigo (array de strings JSON, cada uma `{date: epochMs, goals: [{name, percentCompleted}]}`).
2. Ordena por date. Cada `name` distinto (trim, case-sensitive) → `Goal{type: percent, createdAt: primeira data em que aparece, id: uuid}`.
3. Cada entrada → `DayEntry{date, values[goalId] = percentCompleted}`.
4. Metas presentes na última entrada → ativas. Demais → `archivedAt = (última aparição + 1 dia)`.
5. Grava arquivo, remove chaves `userData` e `beforeDelete`. `nickname` e `themeDark` migram pra `SettingsRepository` (`themeDark` true → dark, false → light; ausente → system).
6. Teste com fixture do JSON real atual (`test/fixtures/v1_userdata.json`).

## Seção 2 — Engine de consistência

Classe pura (sem Flutter), instanciada com `AppData`, `threshold`, `today`.

```dart
bool isGoalDone(Goal g, double v);        // check: v == 100; percent: v >= threshold
double? dayAverage(DateTime d);           // média sobre metas ativas em d; null se nenhuma ativa
bool isDayConsistent(DateTime d);         // avg != null && avg >= threshold
int globalStreak(); int globalBest();
int goalStreak(Goal g); int goalBest(Goal g);
double goalRate(Goal g, int lastNDays);   // done / dias ativos nos últimos N
Map<DateTime, double?> heatmap(int year);
```

Streak global em `today`: maior k tal que `today-1 … today-k` todos consistentes; +1 se `today` consistente. Dia sem entry = não consistente. Dia sem meta ativa = pulado (não conta, não quebra). Por meta: idem com universo = dias em que meta é ativa e `isGoalDone`.

Threshold mudou → recalcula tudo (comportamento intencional; settings avisa "afeta o histórico").

Testes tabelados: vazio; só hoje; gap; meta criada no meio; arquivada; threshold 100; check vs percent; dia sem metas ativas no meio do streak.

## Seção 3 — Telas e fluxos

**Home**
- "Olá, {nick}", streak global grande + recorde.
- Lista de metas ativas: nome (tap → detalhe), 🔥 streak da meta, controle por tipo (checkbox | slider 0–100 divisions 4). Sempre editável.
- Botão grande "Salvar hoje": estados não-salvo / salvo; cor = `Utilities.activeColor(dayAverage)`. Mexer após salvar volta a não-salvo.
- "+ nova meta" → bottom sheet (nome, tipo).
- Sem metas e `onboardingDone == false` → onboarding (fase 7); antes disso, botão "+".

**Detalhe de meta** (push)
- Nome editável, tipo (troca livre; valores antigos mantidos).
- Streak atual, recorde, % 7d, % 30d, mini-heatmap 30d.
- Arquivar (confirm) | Restaurar.

**Calendar**
- Toggle Mês | Ano.
- Mês: grid próprio, dia colorido por `dayAverage` (cinza sem dados; escala vermelho→verde via `activeColor`), hoje com borda. Tap → painel abaixo com metas ativas do dia e valores. Se `today-7 ≤ dia ≤ today` → editável + salvar; senão leitura.
- Ano: heatmap semanas×dias estilo GitHub. Tap no dia → abre mês.

**Settings**
- Perfil: nickname.
- Consistência: threshold (slider, aviso), metas arquivadas (lista → restaurar).
- Lembrete: on/off + horário.
- Dados: exportar, importar (substituir | mesclar), apagar tudo (undo 5s).
- Aparência: sistema | claro | escuro.
- Sobre, enviar opinião.

**Navegação:** `NavigationBar` M3, 3 destinos, sem FAB, sem PageView. Home inicial.

**Widget Android:** streak + "hoje salvo ✓ / pendente"; tap abre app.

## Seção 4 — Notificações, export/import, erros, i18n, widget

**Notificações** — `flutter_local_notifications` + `timezone`.
- `zonedSchedule` diário no horário; ao `saveDay(today)` cancela e reagenda pra amanhã; no `main` sempre reagenda (idempotente); `RECEIVE_BOOT_COMPLETED`.
- Android 13+: pede `POST_NOTIFICATIONS` ao ligar toggle; negado → toggle off + snackbar.
- Texto: "{nick}, ainda não marcou hoje 🔥 streak: N".

**Export/import**
- Export: `share_plus` do arquivo (`consistency-YYYY-MM-DD.json`).
- Import: `file_picker` → valida schema → dialog Substituir | Mesclar (goals por id, entries por date, `updatedAt` maior vence) → confirm → `AppStore.replaceAll/merge`.
- Parse inválido → snackbar, nada muda.

**Erros/edge cases**
- Load falha (arquivo e `.bak`) → tela erro com "tentar de novo" e "exportar arquivo bruto".
- Save falha → snackbar; memória mantida; retry no próximo save.
- Troca de dia com app aberto → `today` recalculado em `resumed` (`WidgetsBindingObserver`) e no build via `select`.
- Apagar tudo → renomeia arquivo pra `.deleted`; undo 5s restaura; após timeout ou próximo save, apaga.

**i18n** — `flutter_localizations` + `intl`, `l10n.yaml`, `app_pt.arb`/`app_en.arb`, idioma do sistema, fallback en, datas via `DateFormat`.

**Widget Android** — `home_widget`. A cada `saveDay`/mudança relevante o app grava `streak`, `todayDone`, `nick`; layout XML simples; tap → abre Home; `WorkManager` diário 00:05 pra marcar "pendente" no novo dia.

**Design (0-D)** — claude-design MCP: 1 projeto, telas acima, light+dark, tokens a partir das cores atuais. Aprovação por tela é pré-requisito das fases 4, 5, 7, 9.

## Dependências novas (por fase)

| Fase | Pacotes |
|---|---|
| 1 | `provider` |
| 2 | `path_provider`, `uuid` |
| 6 | `flutter_local_notifications`, `timezone`, `flutter_timezone` |
| 7 | `share_plus`, `file_picker` |
| 8 | `flutter_localizations`, `intl` |
| 9 | `home_widget`, `workmanager` |
| remove (5) | `flutter_calendar_carousel` |

## Testes

- Fase 2: round-trip JSON, escrita atômica/`.bak`, migração com fixture real, `AppStore` mutações.
- Fase 3: engine tabelado (maioria dos testes do projeto).
- Fase 4+: widget tests de fluxo (salvar hoje, arquivar, editar dia passado dentro/fora da janela).
- Fase 7: merge/replace, import inválido.
