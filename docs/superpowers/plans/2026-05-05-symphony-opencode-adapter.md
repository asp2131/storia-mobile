# Symphony OpenCode Adapter — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add OpenCode as an alternative agent backend to the Symphony Elixir orchestrator, alongside the existing Codex app-server backend.

**Architecture:** Create a new `SymphonyElixir.OpenCode.AppServer` module that spawns `opencode run --format json` subprocesses per turn and translates NDJSON events into the existing orchestrator message format. The AgentRunner dispatches to either backend based on a config flag. No changes to the Orchestrator — it already handles `{:codex_worker_update, ...}` messages generically.

**Tech Stack:** Elixir 1.19, OTP 28, Ecto (schema only), Jason (JSON), Port (subprocess)

**Source repo:** `~/Documents/experiments/symphony/elixir/`

---

## Context: How Symphony's Agent Backend Works

The orchestrator dispatches issues to `AgentRunner.run/3`. The runner:
1. Creates a workspace via `Workspace.create_for_issue/2`
2. Runs `before_run` hook
3. Calls `AppServer.start_session/2` → returns session map
4. Loops up to `max_turns` times: `AppServer.run_turn/4` → returns `{:ok, turn_session}`
5. Calls `AppServer.stop_session/1`
6. Runs `after_run` hook

Events flow from AppServer → AgentRunner's `on_message` callback → Orchestrator via `send(recipient, {:codex_worker_update, issue_id, message})`.

**Codex.AppServer** uses a persistent JSON-RPC 2.0 session over stdio (one port, many turns).

**OpenCode.AppServer** uses fire-and-forget subprocess invocations (`opencode run --format json`), one per turn. Session continuity is achieved via OpenCode's `-s <sessionID>` continuation flag.

---

## File Map

| Action | File | Purpose |
|--------|------|---------|
| Create | `lib/symphony_elixir/opencode/app_server.ex` | OpenCode subprocess client |
| Create | `lib/symphony_elixir/opencode/event_parser.ex` | NDJSON event → orchestrator message translation |
| Modify | `lib/symphony_elixir/config/schema.ex` | Add `OpenCode` embedded schema |
| Modify | `lib/symphony_elixir/config.ex` | Add `opencode_runtime_settings/0` helper |
| Modify | `lib/symphony_elixir/agent_runner.ex` | Dispatch to backend based on config |
| Create | `test/symphony_elixir/opencode/app_server_test.exs` | Unit tests for OpenCode AppServer |
| Create | `test/symphony_elixir/opencode/event_parser_test.exs` | Unit tests for event parsing |
| Modify | `test/symphony_elixir/agent_runner_test.exs` | Add backend dispatch tests |
| Modify | `test/symphony_elixir/config/schema_test.exs` | Add OpenCode config validation tests |

---

### Task 1: Add OpenCode Config Schema

**Files:**
- Modify: `lib/symphony_elixir/config/schema.ex:153-200` (after `Codex` module)
- Modify: `lib/symphony_elixir/config/schema.ex:264-274` (add `embeds_one :opencode`)

**Step 1: Define the OpenCode schema module**

Add after the `Codex` module definition in `config/schema.ex` (after line 200):

```elixir
defmodule OpenCode do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field(:command, :string, default: "opencode run")
    field(:model, :string, default: "opencode/claude-sonnet-4-5")
    field(:dangerously_skip_permissions, :boolean, default: true)
    field(:format, :string, default: "json")
    field(:turn_timeout_ms, :integer, default: 3_600_000)
    field(:stall_timeout_ms, :integer, default: 300_000)
    field(:read_timeout_ms, :integer, default: 5_000)
    field(:agent, :string)
    field(:thinking, :boolean, default: false)
    field(:variant, :string)
    field(:extra_args, {:array, :string}, default: [])
  end

  @spec changeset(%__MODULE__{}, map()) :: Ecto.Changeset.t()
  def changeset(schema, attrs) do
    schema
    |> cast(
      attrs,
      [
        :command,
        :model,
        :dangerously_skip_permissions,
        :format,
        :turn_timeout_ms,
        :stall_timeout_ms,
        :read_timeout_ms,
        :agent,
        :thinking,
        :variant,
        :extra_args
      ],
      empty_values: []
    )
    |> validate_required([:command])
    |> validate_number(:turn_timeout_ms, greater_than: 0)
    |> validate_number(:read_timeout_ms, greater_than: 0)
    |> validate_number(:stall_timeout_ms, greater_than_or_equal_to: 0)
    |> validate_inclusion(:format, ["json", "text"])
    |> validate_inclusion(:variant, ["high", "max", "minimal", nil])
  end
end
```

**Step 2: Add `embeds_one :opencode` to the root schema**

In the `changeset/1` function of the root schema (around line 354-366), add:

```elixir
|> cast_embed(:opencode, with: &OpenCode.changeset/2)
```

And add to the embedded_schema block (around line 264-274):

```elixir
embeds_one(:opencode, OpenCode, on_replace: :update, defaults_to_struct: true)
```

**Step 3: Add `backend` field to Agent schema**

In the `Agent` embedded_schema (around line 130-135), add:

```elixir
field(:backend, :string, default: "codex")
```

And add `:backend` to its cast fields. Add validation:

```elixir
|> validate_inclusion(:backend, ["codex", "opencode"])
```

**Step 4: Add `resolve_opencode_settings/1` to `finalize_settings/1`**

In the `finalize_settings/1` function (around line 368-387), add opencode normalization:

```elixir
opencode = normalize_optional_map(settings.opencode)
%{settings | tracker: tracker, workspace: workspace, codex: codex, opencode: opencode}
```

**Step 5: Run existing tests to verify no regressions**

Run: `mix test test/symphony_elixir/config/schema_test.exs`
Expected: All existing tests pass

**Step 6: Commit**

```bash
git add lib/symphony_elixir/config/schema.ex
git commit -m "feat(config): add OpenCode schema and backend selector to config"
```

---

### Task 2: Add OpenCode Config Helpers

**Files:**
- Modify: `lib/symphony_elixir/config.ex`

**Step 1: Add `opencode_runtime_settings/0` function**

Add after `codex_runtime_settings/2` (around line 115):

```elixir
@spec opencode_runtime_settings() :: map() | {:error, term()}
def opencode_runtime_settings do
  case settings() do
    {:ok, settings} ->
      {:ok,
       %{
         command: settings.opencode.command,
         model: settings.opencode.model,
         dangerously_skip_permissions: settings.opencode.dangerously_skip_permissions,
         format: settings.opencode.format,
         turn_timeout_ms: settings.opencode.turn_timeout_ms,
         stall_timeout_ms: settings.opencode.stall_timeout_ms,
         read_timeout_ms: settings.opencode.read_timeout_ms,
         agent: settings.opencode.agent,
         thinking: settings.opencode.thinking,
         variant: settings.opencode.variant,
         extra_args: settings.opencode.extra_args
       }}

    {:error, reason} ->
      {:error, reason}
  end
end

@spec opencode_runtime_settings!() :: map()
def opencode_runtime_settings! do
  case opencode_runtime_settings() do
    {:ok, settings} -> settings
    {:error, reason} -> raise ArgumentError, message: "Invalid OpenCode config: #{inspect(reason)}"
  end
end
```

**Step 2: Add `using_opencode?/0` helper**

```elixir
@spec using_opencode?() :: boolean()
def using_opencode? do
  settings!().agent.backend == "opencode"
end
```

**Step 3: Run tests**

Run: `mix test test/symphony_elixir/config_test.exs`
Expected: PASS

**Step 4: Commit**

```bash
git add lib/symphony_elixir/config.ex
git commit -m "feat(config): add OpenCode runtime settings and backend helper"
```

---

### Task 3: Create OpenCode Event Parser

**Files:**
- Create: `lib/symphony_elixir/opencode/event_parser.ex`
- Create: `test/symphony_elixir/opencode/event_parser_test.exs`

**Step 1: Create the event parser module**

```elixir
defmodule SymphonyElixir.OpenCode.EventParser do
  @moduledoc """
  Parses OpenCode NDJSON events and translates them to the orchestrator's
  message format (`{:codex_worker_update, issue_id, message}`).
  """

  require Logger

  @type parsed_event ::
          {:turn_completed, map()}
          | {:turn_failed, map()}
          | {:notification, map()}
          | {:token_usage, map()}
          | {:skip, String.t()}
          | :empty

  @spec parse_line(String.t(), map()) :: parsed_event()
  def parse_line(line, metadata \\ %{}) do
    line
    |> String.trim()
    |> case do
      "" ->
        :empty

      json_line ->
        case Jason.decode(json_line) do
          {:ok, event} -> translate_event(event, metadata)
          {:error, _} -> {:skip, json_line}
        end
    end
  end

  @spec translate_event(map(), map()) :: parsed_event()
  def translate_event(%{"type" => "step_finish"} = event, _metadata) do
    reason = get_in(event, ["part", "reason"]) || "unknown"
    usage = extract_usage(event)

    case reason do
      "stop" ->
        {:turn_completed,
         %{
           usage: usage,
           timestamp: parse_timestamp(event["timestamp"]),
           raw: event
         }}

      "max_tokens" ->
        {:turn_completed,
         %{
           usage: usage,
           reason: :max_tokens,
           timestamp: parse_timestamp(event["timestamp"]),
           raw: event
         }}

      _ ->
        {:turn_failed,
         %{
           reason: reason,
           usage: usage,
           timestamp: parse_timestamp(event["timestamp"]),
           raw: event
         }}
    end
  end

  def translate_event(%{"type" => "step_start"} = event, _metadata) do
    {:notification,
     %{
       event: :step_started,
       timestamp: parse_timestamp(event["timestamp"]),
       raw: event
     }}
  end

  def translate_event(%{"type" => "text"} = event, _metadata) do
    text = get_in(event, ["part", "text"]) || ""

    {:notification,
     %{
       event: :text_output,
       text: text,
       timestamp: parse_timestamp(event["timestamp"]),
       raw: event
     }}
  end

  def translate_event(%{"type" => "tool_use"} = event, _metadata) do
    tool_name = get_in(event, ["part", "name"]) || "unknown"

    {:notification,
     %{
       event: :tool_call,
       tool_name: tool_name,
       timestamp: parse_timestamp(event["timestamp"]),
       raw: event
     }}
  end

  def translate_event(%{"type" => "tool_result"} = event, _metadata) do
    {:notification,
     %{
       event: :tool_result,
       timestamp: parse_timestamp(event["timestamp"]),
       raw: event
     }}
  end

  def translate_event(%{"type" => "error"} = event, _metadata) do
    error_message = get_in(event, ["error", "message"]) || event["message"] || "unknown"

    {:turn_failed,
     %{
       reason: error_message,
       timestamp: parse_timestamp(event["timestamp"]),
       raw: event
     }}
  end

  def translate_event(%{"type" => type} = event, _metadata) when is_binary(type) do
    {:notification,
     %{
       event: String.to_atom(type) rescue String.to_existing_atom(type),
       timestamp: parse_timestamp(event["timestamp"]),
       raw: event
     }}
  end

  def translate_event(event, _metadata) do
    {:notification,
     %{
       event: :unknown,
       timestamp: nil,
       raw: event
     }}
  end

  @spec extract_usage(map()) :: map()
  def extract_usage(event) do
    usage =
      get_in(event, ["part", "usage"]) ||
        get_in(event, ["usage"]) ||
        %{}

    %{
      input_tokens: Map.get(usage, "input_tokens", 0) || 0,
      output_tokens: Map.get(usage, "output_tokens", 0) || 0,
      total_tokens: Map.get(usage, "total_tokens", 0) || 0,
      reasoning_tokens: Map.get(usage, "reasoning_tokens", 0) || 0,
      cache_tokens: Map.get(usage, "cache_tokens", 0) || 0
    }
  end

  @spec extract_session_id(String.t()) :: String.t() | nil
  def extract_session_id(line) do
    case Jason.decode(line) do
      {:ok, %{"sessionID" => session_id}} when is_binary(session_id) -> session_id
      _ -> nil
    end
  end

  @spec extract_cost(map()) :: float() | nil
  def extract_cost(event) do
    get_in(event, ["part", "cost"]) || get_in(event, ["cost"])
  end

  defp parse_timestamp(nil), do: DateTime.utc_now()

  defp parse_timestamp(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp, :millisecond)
  rescue
    _ -> DateTime.utc_now()
  end

  defp parse_timestamp(_), do: DateTime.utc_now()
end
```

**Step 2: Create the test file**

```elixir
defmodule SymphonyElixir.OpenCode.EventParserTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.OpenCode.EventParser

  describe "parse_line/2" do
    test "returns :empty for blank lines" do
      assert :empty = EventParser.parse_line("")
      assert :empty = EventParser.parse_line("  ")
    end

    test "returns {:skip, _} for non-JSON lines" do
      assert {:skip, "not json"} = EventParser.parse_line("not json")
    end

    test "parses step_finish with stop reason" do
      line = ~s({"type":"step_finish","timestamp":1714920000000,"part":{"reason":"stop","tokens":{"total":150}}})

      assert {:turn_completed, %{usage: usage, timestamp: %DateTime{}}} =
               EventParser.parse_line(line)

      assert usage.total_tokens == 150
    end

    test "parses step_finish with error reason" do
      line = ~s({"type":"step_finish","timestamp":1714920000000,"part":{"reason":"error"}})

      assert {:turn_failed, %{reason: "error"}} = EventParser.parse_line(line)
    end

    test "parses error event" do
      line = ~s({"type":"error","error":{"message":"rate limit exceeded"}})

      assert {:turn_failed, %{reason: "rate limit exceeded"}} = EventParser.parse_line(line)
    end

    test "parses text event" do
      line = ~s({"type":"text","timestamp":1714920000000,"part":{"text":"Hello"}})

      assert {:notification, %{event: :text_output, text: "Hello"}} =
               EventParser.parse_line(line)
    end

    test "parses tool_use event" do
      line = ~s({"type":"tool_use","timestamp":1714920000000,"part":{"name":"bash"}})

      assert {:notification, %{event: :tool_call, tool_name: "bash"}} =
               EventParser.parse_line(line)
    end
  end

  describe "extract_session_id/1" do
    test "extracts sessionID from JSON line" do
      line = ~s({"type":"text","sessionID":"abc-123","part":{"text":"hi"}})
      assert "abc-123" = EventParser.extract_session_id(line)
    end

    test "returns nil when no sessionID" do
      line = ~s({"type":"text","part":{"text":"hi"}})
      assert nil == EventParser.extract_session_id(line)
    end

    test "returns nil for non-JSON" do
      assert nil == EventParser.extract_session_id("not json")
    end
  end

  describe "extract_usage/1" do
    test "extracts tokens from part.usage" do
      event = %{
        "type" => "step_finish",
        "part" => %{
          "usage" => %{
            "input_tokens" => 100,
            "output_tokens" => 50,
            "total_tokens" => 150
          }
        }
      }

      usage = EventParser.extract_usage(event)
      assert usage.input_tokens == 100
      assert usage.output_tokens == 50
      assert usage.total_tokens == 150
    end

    test "returns zeros when no usage" do
      event = %{"type" => "text"}
      usage = EventParser.extract_usage(event)
      assert usage.input_tokens == 0
      assert usage.output_tokens == 0
      assert usage.total_tokens == 0
    end
  end
end
```

**Step 3: Run tests**

Run: `mix test test/symphony_elixir/opencode/event_parser_test.exs`
Expected: All tests pass

**Step 4: Commit**

```bash
git add lib/symphony_elixir/opencode/ test/symphony_elixir/opencode/
git commit -m "feat(opencode): add NDJSON event parser for OpenCode output"
```

---

### Task 4: Create OpenCode AppServer

**Files:**
- Create: `lib/symphony_elixir/opencode/app_server.ex`
- Create: `test/symphony_elixir/opencode/app_server_test.exs`

**Step 1: Create the OpenCode AppServer module**

```elixir
defmodule SymphonyElixir.OpenCode.AppServer do
  @moduledoc """
  Agent backend for OpenCode. Spawns `opencode run --format json` subprocesses
  per turn and translates NDJSON events into the orchestrator's message format.

  Unlike `Codex.AppServer` which maintains a persistent JSON-RPC session over stdio,
  this module spawns a new OpenCode process for each turn. Session continuity is
  achieved via OpenCode's `-s <sessionID>` continuation flag.
  """

  require Logger
  alias SymphonyElixir.{Config, OpenCode.EventParser}

  @port_line_bytes 1_048_576

  @type session :: %{
          session_id: String.t() | nil,
          workspace: Path.t(),
          worker_host: String.t() | nil,
          opencode_session_id: String.t() | nil
        }

  @spec start_session(Path.t(), keyword()) :: {:ok, session()} | {:error, term()}
  def start_session(workspace, opts \\ []) do
    worker_host = Keyword.get(opts, :worker_host)

    case validate_workspace(workspace, worker_host) do
      {:ok, expanded_workspace} ->
        {:ok,
         %{
           session_id: nil,
           workspace: expanded_workspace,
           worker_host: worker_host,
           opencode_session_id: nil
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec run_turn(session(), String.t(), map(), keyword()) :: {:ok, session()} | {:error, term()}
  def run_turn(session, prompt, issue, opts \\ []) do
    on_message = Keyword.get(opts, :on_message, fn _ -> :ok end)
    config = Config.opencode_runtime_settings!()

    args = build_command_args(config, session, prompt, issue)

    Logger.info("OpenCode turn starting for #{issue_context(issue)} workspace=#{session.workspace}")

    case spawn_opencode(args, session.workspace, config, on_message, issue) do
      {:ok, result} ->
        new_session_id = Map.get(result, :session_id) || session.opencode_session_id

        Logger.info("OpenCode turn completed for #{issue_context(issue)}")

        {:ok,
         %{
           session
           | session_id: Map.get(result, :session_id),
             opencode_session_id: new_session_id
         }}

      {:error, reason} ->
        Logger.warning("OpenCode turn failed for #{issue_context(issue)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @spec stop_session(session()) :: :ok
  def stop_session(_session), do: :ok

  defp build_command_args(config, session, prompt, issue) do
    base_args = String.split(config.command)

    model_args = if config.model, do: ["-m", config.model], else: []

    format_args = ["--format", config.format || "json"]

    permission_args =
      if config.dangerously_skip_permissions,
        do: ["--dangerously-skip-permissions"],
        else: []

    agent_args = if config.agent, do: ["--agent", config.agent], else: []
    thinking_args = if config.thinking, do: ["--thinking"], else: []
    variant_args = if config.variant, do: ["--variant", config.variant], else: []

    dir_args = ["--dir", session.workspace]

    continuation_args =
      if session.opencode_session_id do
        ["-s", session.opencode_session_id]
      else
        []
      end

    extra_args = config.extra_args || []

    base_args ++
      model_args ++
      format_args ++
      permission_args ++
      agent_args ++
      thinking_args ++
      variant_args ++
      dir_args ++
      continuation_args ++
      extra_args ++
      [prompt]
  end

  defp spawn_opencode(args, workspace, config, on_message, issue) do
    executable = System.find_executable("bash")

    if is_nil(executable) do
      {:error, :bash_not_found}
    else
      command_string = Enum.join(args, " ")

      port =
        Port.open(
          {:spawn_executable, String.to_charlist(executable)},
          [
            :binary,
            :exit_status,
            :stderr_to_stdout,
            args: [~c"-lc", String.to_charlist(command_string)],
            cd: String.to_charlist(workspace),
            line: @port_line_bytes
          ]
        )

      receive_loop(port, on_message, config.turn_timeout_ms, "", issue, %{
        session_id: nil,
        tokens: %{input_tokens: 0, output_tokens: 0, total_tokens: 0}
      })
    end
  end

  defp receive_loop(port, on_message, timeout_ms, pending_line, issue, acc) do
    receive do
      {^port, {:data, {:eol, chunk}}} ->
        complete_line = pending_line <> to_string(chunk)
        handle_line(port, on_message, complete_line, timeout_ms, issue, acc)

      {^port, {:data, {:noeol, chunk}}} ->
        receive_loop(port, on_message, timeout_ms, pending_line <> to_string(chunk), issue, acc)

      {^port, {:exit_status, status}} ->
        if status == 0 do
          {:ok, acc}
        else
          {:error, {:exit_status, status}}
        end
    after
      timeout_ms ->
        stop_port(port)
        {:error, :turn_timeout}
    end
  end

  defp handle_line(port, on_message, line, timeout_ms, issue, acc) do
    case EventParser.parse_line(line) do
      :empty ->
        receive_loop(port, on_message, timeout_ms, "", issue, acc)

      {:skip, _raw} ->
        receive_loop(port, on_message, timeout_ms, "", issue, acc)

      {:turn_completed, event} ->
        new_acc = %{
          acc
          | session_id: extract_session_id_from_line(line) || acc.session_id,
            tokens: merge_tokens(acc.tokens, event.usage)
        }

        emit_message(
          on_message,
          :turn_completed,
          Map.put(event, :session_id, new_acc.session_id),
          issue
        )

        receive_loop(port, on_message, timeout_ms, "", issue, new_acc)

      {:turn_failed, event} ->
        emit_message(on_message, :turn_failed, event, issue)
        {:error, {:turn_failed, event.reason}}

      {:notification, event} ->
        emit_message(on_message, event.event, event, issue)
        receive_loop(port, on_message, timeout_ms, "", issue, acc)
    end
  end

  defp emit_message(on_message, event, details, issue) do
    message =
      details
      |> Map.put(:event, event)
      |> Map.put(:timestamp, DateTime.utc_now())

    on_message.(message)
  end

  defp extract_session_id_from_line(line) do
    case EventParser.extract_session_id(line) do
      nil ->
        case Jason.decode(line) do
          {:ok, %{"sessionID" => id}} when is_binary(id) -> id
          _ -> nil
        end

      session_id ->
        session_id
    end
  end

  defp merge_tokens(current, usage) do
    %{
      input_tokens: current.input_tokens + Map.get(usage, :input_tokens, 0),
      output_tokens: current.output_tokens + Map.get(usage, :output_tokens, 0),
      total_tokens: current.total_tokens + Map.get(usage, :total_tokens, 0)
    }
  end

  defp validate_workspace(workspace, nil) when is_binary(workspace) do
    expanded = Path.expand(workspace)

    if File.dir?(expanded) do
      {:ok, expanded}
    else
      {:error, {:workspace_not_found, expanded}}
    end
  end

  defp validate_workspace(workspace, worker_host)
       when is_binary(workspace) and is_binary(worker_host) do
    if String.trim(workspace) != "" do
      {:ok, workspace}
    else
      {:error, {:empty_remote_workspace, worker_host}}
    end
  end

  defp stop_port(port) when is_port(port) do
    try do
      Port.close(port)
    rescue
      ArgumentError -> :ok
    end
  end

  defp stop_port(_port), do: :ok

  defp issue_context(%{id: issue_id, identifier: identifier}) do
    "issue_id=#{issue_id} issue_identifier=#{identifier}"
  end

  defp issue_context(%{}), do: ""
end
```

**Step 2: Create the test file**

```elixir
defmodule SymphonyElixir.OpenCode.AppServerTest do
  use ExUnit.Case, async: true

  alias SymphonyElixir.OpenCode.AppServer

  @test_workspace System.tmp_dir!()

  describe "start_session/2" do
    test "returns session with workspace" do
      assert {:ok, session} = AppServer.start_session(@test_workspace)
      assert session.workspace == Path.expand(@test_workspace)
      assert session.opencode_session_id == nil
    end

    test "returns error for non-existent workspace" do
      assert {:error, {:workspace_not_found, _}} =
               AppServer.start_session("/nonexistent/path")
    end
  end

  describe "stop_session/1" do
    test "always returns :ok" do
      session = %{
        session_id: nil,
        workspace: @test_workspace,
        worker_host: nil,
        opencode_session_id: nil
      }

      assert :ok = AppServer.stop_session(session)
    end
  end
end
```

**Step 3: Run tests**

Run: `mix test test/symphony_elixir/opencode/app_server_test.exs`
Expected: All tests pass

**Step 4: Commit**

```bash
git add lib/symphony_elixir/opencode/app_server.ex test/symphony_elixir/opencode/app_server_test.exs
git commit -m "feat(opencode): add OpenCode AppServer backend"
```

---

### Task 5: Wire AgentRunner to Dispatch by Backend

**Files:**
- Modify: `lib/symphony_elixir/agent_runner.ex`

**Step 1: Add backend dispatch to `run_codex_turns/5`**

Replace the `run_codex_turns/5` function (lines 79-90) with:

```elixir
defp run_codex_turns(workspace, issue, codex_update_recipient, opts, worker_host) do
  max_turns = Keyword.get(opts, :max_turns, Config.settings!().agent.max_turns)
  issue_state_fetcher = Keyword.get(opts, :issue_state_fetcher, &Tracker.fetch_issue_states_by_ids/1)
  backend = Config.settings!().agent.backend

  case start_backend_session(backend, workspace, worker_host) do
    {:ok, session} ->
      try do
        do_run_turns(backend, session, workspace, issue, codex_update_recipient, opts, issue_state_fetcher, 1, max_turns)
      after
        stop_backend_session(backend, session)
      end

    {:error, reason} ->
      {:error, reason}
  end
end
```

**Step 2: Add backend dispatch helpers**

Add these private functions after `run_codex_turns/5`:

```elixir
defp start_backend_session("opencode", workspace, worker_host) do
  SymphonyElixir.OpenCode.AppServer.start_session(workspace, worker_host: worker_host)
end

defp start_backend_session(_codex, workspace, worker_host) do
  SymphonyElixir.Codex.AppServer.start_session(workspace, worker_host: worker_host)
end

defp stop_backend_session("opencode", session) do
  SymphonyElixir.OpenCode.AppServer.stop_session(session)
end

defp stop_backend_session(_codex, session) do
  SymphonyElixir.Codex.AppServer.stop_session(session)
end

defp run_backend_turn("opencode", session, prompt, issue, opts) do
  SymphonyElixir.OpenCode.AppServer.run_turn(session, prompt, issue, opts)
end

defp run_backend_turn(_codex, session, prompt, issue, opts) do
  SymphonyElixir.Codex.AppServer.run_turn(session, prompt, issue, opts)
end
```

**Step 3: Update `do_run_codex_turns/8` to use backend dispatch**

Replace the direct `AppServer.run_turn` call (line 95-101) with:

```elixir
defp do_run_codex_turns(backend, app_session, workspace, issue, codex_update_recipient, opts, issue_state_fetcher, turn_number, max_turns) do
  prompt = build_turn_prompt(issue, opts, turn_number, max_turns)

  with {:ok, turn_session} <-
         run_backend_turn(
           backend,
           app_session,
           prompt,
           issue,
           on_message: codex_message_handler(codex_update_recipient, issue)
         ) do
    Logger.info("Completed agent run for #{issue_context(issue)} session_id=#{turn_session[:session_id]} workspace=#{workspace} turn=#{turn_number}/#{max_turns}")

    case continue_with_issue?(issue, issue_state_fetcher) do
      {:continue, refreshed_issue} when turn_number < max_turns ->
        Logger.info("Continuing agent run for #{issue_context(refreshed_issue)} after normal turn completion turn=#{turn_number}/#{max_turns}")

        do_run_codex_turns(
          backend,
          app_session,
          workspace,
          refreshed_issue,
          codex_update_recipient,
          opts,
          issue_state_fetcher,
          turn_number + 1,
          max_turns
        )

      {:continue, refreshed_issue} ->
        Logger.info("Reached agent.max_turns for #{issue_context(refreshed_issue)} with issue still active; returning control to orchestrator")
        :ok

      {:done, _refreshed_issue} ->
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Step 4: Update the call site in `run_codex_turns/5`**

The `do_run_codex_turns` call on line 85 needs the `backend` parameter prepended:

```elixir
do_run_turns(backend, session, workspace, issue, codex_update_recipient, opts, issue_state_fetcher, 1, max_turns)
```

**Step 5: Run all tests**

Run: `mix test test/symphony_elixir/agent_runner_test.exs`
Expected: All existing tests pass

**Step 6: Commit**

```bash
git add lib/symphony_elixir/agent_runner.ex
git commit -m "feat(agent_runner): dispatch to OpenCode or Codex based on config"
```

---

### Task 6: Add WORKFLOW.md Example Config

**Files:**
- Create: `WORKFLOW.opencode.md` (example workflow file for OpenCode mode)

**Step 1: Create the example workflow file**

```markdown
---
tracker:
  kind: linear
  project_slug: "storia-web-b2f648c17c65"
  active_states:
    - Todo
    - In Progress
  terminal_states:
    - Done
    - Canceled
    - Duplicate
    - Backlog
polling:
  interval_ms: 30000
workspace:
  root: ~/code/symphony-workspaces
hooks:
  after_create: |
    git clone --depth 1 git@github.com:org/repo.git .
  before_run: |
    git pull
  after_run: |
    echo done
agent:
  backend: opencode
  max_concurrent_agents: 2
  max_turns: 20
opencode:
  command: "opencode run"
  model: "opencode/claude-sonnet-4-5"
  dangerously_skip_permissions: true
  format: "json"
  turn_timeout_ms: 3600000
  stall_timeout_ms: 300000
  read_timeout_ms: 5000
---

You are working on Linear ticket {{ issue.identifier }}.

Title: {{ issue.title }}

{% if issue.description %}
Body:
{{ issue.description }}
{% endif %}
```

**Step 2: Commit**

```bash
git add WORKFLOW.opencode.md
git commit -m "docs: add example WORKFLOW.md for OpenCode backend"
```

---

### Task 7: Integration Test with Live OpenCode

**Files:**
- Create: `test/symphony_elixir/opencode/integration_test.exs`

**Step 1: Create integration test**

This test verifies the full pipeline: AgentRunner → OpenCode.AppServer → EventParser → message format.

```elixir
defmodule SymphonyElixir.OpenCode.IntegrationTest do
  @moduletag :integration

  use ExUnit.Case

  alias SymphonyElixir.OpenCode.{AppServer, EventParser}

  @test_workspace System.tmp_dir!()

  describe "full turn lifecycle" do
    @tag timeout: 60_000
    test "spawns opencode and parses output" do
      # Skip if opencode not available
      if is_nil(System.find_executable("opencode")) do
        IO.puts("Skipping: opencode not on PATH")
        assert true
      else
        {:ok, session} = AppServer.start_session(@test_workspace)

        messages =
          Agent.start_link(fn -> [] end)
          |> elem(1)
          |> tap(fn pid ->
            Agent.update(pid, fn _ -> [] end)
          end)

        on_message = fn message ->
          Agent.update(messages, fn acc -> [message | acc] end)
        end

        case AppServer.run_turn(
               session,
               "Say 'hello from opencode integration test' and nothing else.",
               %{id: "test-1", identifier: "TEST-1", title: "Integration Test"},
               on_message: on_message
             ) do
          {:ok, _new_session} ->
            collected = Agent.get(messages, & &1)
            assert length(collected) > 0

          {:error, reason} ->
            flunk("OpenCode turn failed: #{inspect(reason)}")
        end

        AppServer.stop_session(session)
      end
    end
  end
end
```

**Step 2: Run integration test (skips if opencode not installed)**

Run: `mix test test/symphony_elixir/opencode/integration_test.exs --include integration`
Expected: Passes (or skips if opencode not on PATH)

**Step 3: Commit**

```bash
git add test/symphony_elixir/opencode/integration_test.exs
git commit -m "test(opencode): add integration test for full turn lifecycle"
```

---

## Summary

After completing all tasks, the Symphony Elixir codebase will support two agent backends:

| Aspect | Codex (existing) | OpenCode (new) |
|--------|-----------------|----------------|
| Config key | `codex:` | `opencode:` |
| Backend selector | `agent.backend: "codex"` | `agent.backend: "opencode"` |
| Session model | Persistent JSON-RPC over stdio | Fire-and-forget subprocess per turn |
| Turn continuation | Same port, new `turn/start` | `-s <sessionID>` flag |
| Approval handling | Explicit approve/reject protocol | `--dangerously-skip-permissions` |
| Dynamic tools | `linear_graphql` via tool calls | Not yet supported |
| Output format | JSON-RPC 2.0 | NDJSON events |

The Orchestrator, Tracker, Workspace, and PromptBuilder modules are unchanged — the adapter boundary is clean.
