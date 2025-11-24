defmodule Bindocsis.InteractiveEditor do
  @moduledoc """
  Interactive DOCSIS configuration editor with terminal-based interface.

  Provides a user-friendly way to create, edit, and validate DOCSIS configurations
  through an interactive terminal session with real-time feedback and validation.

  ## Features

  - **Interactive TLV editing**: Browse and modify TLVs with guided prompts
  - **Smart value input**: Accepts human-readable values like "591 MHz", "enabled"
  - **Real-time validation**: DOCSIS compliance checking as you edit
  - **Configuration templates**: Quick-start templates for common scenarios
  - **Undo/redo support**: Track changes and revert if needed
  - **Auto-completion**: Suggests TLV types and values
  - **Export options**: Save to binary, JSON, YAML formats

  ## Usage

      # Start interactive editor
      Bindocsis.InteractiveEditor.start()

      # Edit existing configuration
      Bindocsis.InteractiveEditor.edit_file("config.cm")

      # Start with template
      Bindocsis.InteractiveEditor.start_with_template(:residential_basic)
  """

  alias Bindocsis.ConfigAnalyzer
  alias Bindocsis.ConfigValidator
  alias Bindocsis.DocsisSpecs
  alias Bindocsis.Generators.BinaryGenerator
  alias Bindocsis.ValueParser

  @type editor_state :: %{
          tlvs: [map()],
          history: [editor_command()],
          current_path: String.t() | nil,
          docsis_version: String.t(),
          unsaved_changes: boolean(),
          validation_enabled: boolean()
        }

  @type editor_command :: %{
          action: atom(),
          params: map(),
          timestamp: DateTime.t()
        }

  @doc """
  Starts the interactive editor with a new empty configuration.
  """
  @spec start(keyword()) :: :ok
  def start(opts \\ []) do
    IO.puts("""

    🔧 Bindocsis Interactive Configuration Editor
    ============================================

    Welcome to the interactive DOCSIS configuration editor!
    Type 'help' for available commands or 'quit' to exit.
    """)

    initial_state = %{
      tlvs: [],
      history: [],
      current_path: nil,
      docsis_version: Keyword.get(opts, :docsis_version, "3.1"),
      unsaved_changes: false,
      validation_enabled: Keyword.get(opts, :validation, true)
    }

    editor_loop(initial_state)
  end

  @doc """
  Starts the interactive editor with an existing configuration file.
  """
  @spec edit_file(String.t(), keyword()) :: :ok | {:error, String.t()}
  def edit_file(file_path, opts \\ []) do
    case load_configuration(file_path) do
      {:ok, tlvs} ->
        IO.puts("""

        🔧 Bindocsis Interactive Configuration Editor
        ============================================

        Loaded configuration from: #{file_path}
        Found #{length(tlvs)} TLVs

        Type 'help' for available commands or 'quit' to exit.
        """)

        initial_state = %{
          tlvs: tlvs,
          history: [],
          current_path: file_path,
          docsis_version: Keyword.get(opts, :docsis_version, "3.1"),
          unsaved_changes: false,
          validation_enabled: Keyword.get(opts, :validation, true)
        }

        # Show current configuration
        show_configuration(initial_state)
        editor_loop(initial_state)

      {:error, reason} ->
        IO.puts("❌ Error loading configuration: #{reason}")
        {:error, reason}
    end
  end

  @doc """
  Starts the editor with a predefined template.
  """
  @spec start_with_template(atom(), keyword()) :: :ok
  def start_with_template(template_name, opts \\ []) do
    case load_template(template_name) do
      {:ok, tlvs} ->
        IO.puts("""

        🔧 Bindocsis Interactive Configuration Editor
        ============================================

        Started with template: #{template_name}
        Loaded #{length(tlvs)} TLVs

        Type 'help' for available commands or 'quit' to exit.
        """)

        initial_state = %{
          tlvs: tlvs,
          history: [],
          current_path: nil,
          docsis_version: Keyword.get(opts, :docsis_version, "3.1"),
          unsaved_changes: true,
          validation_enabled: Keyword.get(opts, :validation, true)
        }

        show_configuration(initial_state)
        editor_loop(initial_state)

      {:error, reason} ->
        IO.puts("❌ Error loading template: #{reason}")
        {:error, reason}
    end
  end

  # Main editor loop
  defp editor_loop(state) do
    prompt = if state.unsaved_changes, do: "bindocsis*> ", else: "bindocsis> "

    input = IO.gets(prompt)

    case input do
      :eof ->
        IO.puts("\n👋 Goodbye!")
        :ok

      input when is_binary(input) ->
        case String.trim(input) do
          "quit" ->
            handle_quit(state)

          "q" ->
            handle_quit(state)

          "help" ->
            show_help() |> then(fn _ -> editor_loop(state) end)

          "h" ->
            show_help() |> then(fn _ -> editor_loop(state) end)

          "" ->
            editor_loop(state)

          command ->
            case handle_command(command, state) do
              {:continue, new_state} -> editor_loop(new_state)
            end
        end
    end
  end

  # Command handlers
  defp handle_command("list" <> args, state) do
    show_configuration(state, parse_list_args(args))
    {:continue, state}
  end

  defp handle_command("add snmp " <> snmp_spec, state) do
    case parse_snmp_spec(snmp_spec) do
      {:ok, oid, value_type, value} ->
        add_snmp_mib_object(state, oid, value_type, value)

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        {:continue, state}
    end
  end

  defp handle_command("add " <> tlv_spec, state) do
    case parse_tlv_spec(tlv_spec) do
      {:ok, tlv_type, value} ->
        add_tlv(state, tlv_type, value)

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        {:continue, state}
    end
  end

  defp handle_command("edit " <> tlv_ref, state) do
    case parse_tlv_reference(tlv_ref) do
      {:ok, index} ->
        edit_tlv(state, index)

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        {:continue, state}
    end
  end

  defp handle_command("remove " <> tlv_ref, state) do
    case parse_tlv_reference(tlv_ref) do
      {:ok, index} ->
        remove_tlv(state, index)

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        {:continue, state}
    end
  end

  defp handle_command("move " <> move_spec, state) do
    case parse_move_spec(move_spec) do
      {:ok, from_index, to_index} ->
        move_tlv(state, from_index, to_index)

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        {:continue, state}
    end
  end

  defp handle_command("validate", state) do
    validate_configuration(state)
    {:continue, state}
  end

  defp handle_command("save" <> args, state) do
    save_configuration(state, parse_save_args(args))
  end

  defp handle_command("load " <> file_path, state) do
    load_and_replace_configuration(state, String.trim(file_path))
  end

  defp handle_command("template " <> template_name, state) do
    load_template_and_replace(state, String.to_atom(String.trim(template_name)))
  end

  defp handle_command("undo", state) do
    undo_last_change(state)
  end

  defp handle_command("analyze", state) do
    analyze_configuration(state)
    {:continue, state}
  end

  defp handle_command("set " <> setting, state) do
    handle_settings(state, setting)
  end

  defp handle_command("quit", state) do
    handle_quit(state)
  end

  defp handle_command("exit", state) do
    handle_quit(state)
  end

  defp handle_command(unknown_command, state) do
    IO.puts("Unknown command: \"#{unknown_command}\"")
    show_help()
    {:continue, state}
  end

  # TLV manipulation functions
  defp add_tlv(state, tlv_type, value_input) do
    case create_tlv(tlv_type, value_input, state.docsis_version) do
      {:ok, new_tlv} ->
        new_tlvs = state.tlvs ++ [new_tlv]

        new_state = %{
          state
          | tlvs: new_tlvs,
            unsaved_changes: true,
            history: add_to_history(state.history, :add_tlv, %{tlv: new_tlv})
        }

        IO.puts("✅ Added TLV #{tlv_type}: #{get_tlv_name(tlv_type, state.docsis_version)}")

        if state.validation_enabled do
          validate_tlv(new_tlv, state.docsis_version)
        end

        {:continue, new_state}

      {:error, reason} ->
        IO.puts("❌ Error creating TLV: #{reason}")
        {:continue, state}
    end
  end

  defp edit_tlv(state, index) when index >= 0 and index < length(state.tlvs) do
    tlv = Enum.at(state.tlvs, index)
    tlv_name = get_tlv_name(tlv.type, state.docsis_version)

    IO.puts("\n📝 Editing TLV #{tlv.type}: #{tlv_name}")
    IO.puts("Current value: #{format_tlv_value(tlv)}")

    input = IO.gets("Enter new value (or press Enter to keep current): ")

    case input do
      :eof ->
        IO.puts("\nEdit cancelled.")
        {:continue, state}

      input when is_binary(input) ->
        case String.trim(input) do
          "" ->
            IO.puts("Value unchanged.")
            {:continue, state}

          new_value ->
            case create_tlv(tlv.type, new_value, state.docsis_version) do
              {:ok, updated_tlv} ->
                new_tlvs = List.replace_at(state.tlvs, index, updated_tlv)

                new_state = %{
                  state
                  | tlvs: new_tlvs,
                    unsaved_changes: true,
                    history:
                      add_to_history(state.history, :edit_tlv, %{
                        index: index,
                        old_tlv: tlv,
                        new_tlv: updated_tlv
                      })
                }

                IO.puts("✅ Updated TLV #{tlv.type}")

                if state.validation_enabled do
                  validate_tlv(updated_tlv, state.docsis_version)
                end

                {:continue, new_state}

              {:error, reason} ->
                IO.puts("❌ Error updating TLV: #{reason}")
                {:continue, state}
            end
        end
    end
  end

  defp edit_tlv(state, _invalid_index) do
    IO.puts("❌ Invalid TLV index. Use 'list' to see available TLVs.")
    {:continue, state}
  end

  defp remove_tlv(state, index) when index >= 0 and index < length(state.tlvs) do
    tlv = Enum.at(state.tlvs, index)
    tlv_name = get_tlv_name(tlv.type, state.docsis_version)

    input = IO.gets("Remove TLV #{tlv.type} (#{tlv_name})? [y/N]: ")

    case input do
      :eof ->
        IO.puts("\nCancelled.")
        {:continue, state}

      input when is_binary(input) ->
        answer = input |> String.trim() |> String.downcase()

        case answer do
          answer when answer in ["y", "yes"] ->
            new_tlvs = List.delete_at(state.tlvs, index)

            new_state = %{
              state
              | tlvs: new_tlvs,
                unsaved_changes: true,
                history: add_to_history(state.history, :remove_tlv, %{index: index, tlv: tlv})
            }

            IO.puts("✅ Removed TLV #{tlv.type}: #{tlv_name}")
            {:continue, new_state}

          _ ->
            IO.puts("Cancelled.")
            {:continue, state}
        end
    end
  end

  defp remove_tlv(state, _invalid_index) do
    IO.puts("❌ Invalid TLV index. Use 'list' to see available TLVs.")
    {:continue, state}
  end

  defp move_tlv(state, from_index, to_index)
       when from_index >= 0 and from_index < length(state.tlvs) and
              to_index >= 0 and to_index <= length(state.tlvs) do
    if from_index == to_index do
      IO.puts("⚠️  TLV is already at position #{to_index}.")
      {:continue, state}
    else
      tlv = Enum.at(state.tlvs, from_index)
      tlv_name = get_tlv_name(tlv.type, state.docsis_version)

      # Remove from old position and insert at new position
      new_tlvs =
        state.tlvs
        |> List.delete_at(from_index)
        |> List.insert_at(to_index, tlv)

      new_state = %{
        state
        | tlvs: new_tlvs,
          unsaved_changes: true,
          history:
            add_to_history(state.history, :move_tlv, %{
              from_index: from_index,
              to_index: to_index,
              tlv: tlv
            })
      }

      IO.puts("✅ Moved TLV #{tlv.type} (#{tlv_name}) from position #{from_index} to #{to_index}")
      {:continue, new_state}
    end
  end

  defp move_tlv(state, _from_index, _to_index) do
    IO.puts("❌ Invalid TLV index. Use 'list' to see available TLVs.")
    {:continue, state}
  end

  # Configuration display
  defp show_configuration(state, opts \\ []) do
    try do
      if Enum.empty?(state.tlvs) do
        IO.puts("\n📄 Configuration is empty.")
        IO.puts("Use 'add <type> <value>' to add TLVs or 'template <name>' to load a template.")
      else
        verbose = Keyword.get(opts, :verbose, false)

        IO.puts("\n📄 Current Configuration (#{length(state.tlvs)} TLVs):")
        IO.puts(String.duplicate("=", 50))

        state.tlvs
        |> Enum.with_index()
        |> Enum.each(fn {tlv, index} ->
          show_tlv(tlv, index, state.docsis_version, verbose)
        end)

        if state.validation_enabled do
          IO.puts("\n🔍 Quick validation:")
          run_quick_validation_safe(state)
        end
      end
    rescue
      e in ArgumentError ->
        IO.puts("⚠️  Error while displaying configuration: #{Exception.message(e)}")
    end
  end

  defp show_tlv(tlv, index, docsis_version, verbose) do
    tlv_name = get_tlv_name(tlv.type, docsis_version)
    formatted_value = format_tlv_value(tlv)

    IO.puts(
      "#{index |> Integer.to_string() |> String.pad_leading(2)}. TLV #{tlv.type}: #{tlv_name}"
    )

    IO.puts("    Value: #{formatted_value}")

    if verbose do
      case DocsisSpecs.get_tlv_info(tlv.type, docsis_version) do
        {:ok, tlv_info} ->
          IO.puts("    Description: #{tlv_info.description}")
          IO.puts("    Type: #{tlv_info.value_type}")

          if Map.get(tlv, :subtlvs) && length(tlv.subtlvs) > 0 do
            IO.puts("    SubTLVs: #{length(tlv.subtlvs)}")

            # Recursively display nested sub-TLVs with indentation so the
            # user can actually see the full structure they are editing.
            show_subtlvs(tlv.subtlvs, 6)
          end

        {:error, _} ->
          nil
      end
    end

    IO.puts("")
  end

  # Recursively pretty-print sub-TLVs for verbose list output.
  # indent is the number of leading spaces for this level.
  defp show_subtlvs(subtlvs, indent) when is_list(subtlvs) do
    Enum.each(subtlvs, fn subtlv ->
      padding = String.duplicate(" ", indent)

      header =
        case Map.get(subtlv, :name) do
          nil -> "SubTLV #{subtlv.type}"
          name -> "SubTLV #{subtlv.type}: #{name}"
        end

      value_str = format_subtlv_value(subtlv)

      IO.puts("#{padding}#{header} = #{value_str}")

      # If this sub-TLV is itself compound, recurse so the user can see
      # inner sub-TLVs instead of just a "Compound TLV with N sub-TLVs" summary.
      if Map.get(subtlv, :subtlvs) && length(subtlv.subtlvs) > 0 do
        IO.puts("#{padding}  SubTLVs: #{length(subtlv.subtlvs)}")
        show_subtlvs(subtlv.subtlvs, indent + 4)
      end
    end)
  end

  # Run quick validation but guard against low-level ArgumentError so that
  # malformed or unexpected TLVs (e.g., large SNMP objects) don't crash the
  # entire interactive editor session.
  defp run_quick_validation_safe(state) do
    try do
      validate_configuration_summary(state)
    rescue
      e in ArgumentError ->
        IO.puts("   Status: ❓ Quick validation failed: #{Exception.message(e)}")
    end
  end

  defp validate_tlv(tlv, docsis_version) do
    case DocsisSpecs.get_tlv_info(tlv.type, docsis_version) do
      {:ok, _tlv_info} ->
        # TODO: Add individual TLV validation logic
        nil

      {:error, _} ->
        IO.puts("⚠️  Warning: TLV #{tlv.type} is not defined in DOCSIS #{docsis_version}")
    end
  end

  # Help system
  defp show_help do
    IO.puts("""

    📖 Bindocsis Interactive Editor Commands
    ========================================

    📄 Configuration Management:
      list                    - Show all TLVs in current configuration
      list -v                 - Show TLVs with detailed information
      add <type> <value>      - Add new TLV (e.g., 'add 1 591MHz')
      add snmp <oid> <type> <value> - Add SNMP MIB Object (TLV 11)
      edit <index>            - Edit TLV at given index
      remove <index>          - Remove TLV at given index
      move <from> to <to>     - Move TLV from one position to another
      validate                - Run full DOCSIS validation
      analyze                 - Analyze configuration and show summary

    💾 File Operations:
      save                    - Save to current file (if loaded from file)
      save <filename>         - Save to specific file
      save <filename> <format> - Save in specific format (binary/json/yaml)
      load <filename>         - Load configuration from file

    📋 Templates:
      template residential    - Load residential template
      template business       - Load business template
      template basic          - Load basic template

    🔧 Editor Features:
      undo                    - Undo last change
      set validation on/off   - Enable/disable real-time validation
      set version <ver>       - Set DOCSIS version (2.0, 3.0, 3.1, 4.0)

    ❓ Help & Navigation:
      help, h                 - Show this help message
      quit, q                 - Exit editor

    💡 Value Input Examples:
      Frequencies: 591MHz, 591000000, 591 MHz
      IP Addresses: 192.168.1.1
      Boolean: enabled, disabled, on, off, true, false, 1, 0
      Numbers: 123, 0x7B (hex), 0b1111011 (binary)
      Strings: "TFTP Server Name"
      SNMP: add snmp 1.3.6.1.4.1.8595.20.17.1.4.0 integer 2
            add snmp 1.3.6.1.2.1.1.5.0 string "MyModem"

    🎯 Quick Start:
      1. 'template residential' - Load basic residential config
      2. 'list -v' - See what's in the template
      3. 'edit 0' - Modify the first TLV
      4. 'validate' - Check DOCSIS compliance
      5. 'save myconfig.cm' - Save your configuration
    """)
  end

  # Configuration validation
  defp validate_configuration(state) do
    IO.puts("\n🔍 Running DOCSIS Configuration Validation...")

    case generate_binary_config(state.tlvs) do
      {:ok, binary_config} ->
        case ConfigValidator.validate(binary_config, docsis_version: state.docsis_version) do
          {:ok, validation} ->
            show_validation_results(validation)

          {:error, reason} ->
            IO.puts("❌ Validation failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to generate binary configuration: #{reason}")
    end
  end

  defp validate_configuration_summary(state) do
    case generate_binary_config(state.tlvs) do
      {:ok, binary_config} ->
        case ConfigValidator.validate(binary_config, docsis_version: state.docsis_version) do
          {:ok, validation} ->
            status = if validation.is_valid, do: "✅ Valid", else: "❌ Invalid"
            IO.puts("   Status: #{status} (#{validation.compliance_level})")

            if validation.validation_summary.critical_violations > 0 do
              IO.puts(
                "   Critical violations: #{validation.validation_summary.critical_violations}"
              )
            end

          {:error, _} ->
            IO.puts("   Status: ❓ Could not validate")
        end

      {:error, _} ->
        IO.puts("   Status: ❓ Configuration incomplete")
    end
  end

  defp show_validation_results(validation) do
    IO.puts("Validation Results:")
    IO.puts("================")

    status_icon = if validation.is_valid, do: "✅", else: "❌"

    IO.puts(
      "Overall Status: #{status_icon} #{String.upcase(to_string(validation.compliance_level))}"
    )

    IO.puts("DOCSIS Version: #{validation.docsis_version}")

    summary = validation.validation_summary

    IO.puts(
      "Violations: #{summary.total_violations} (Critical: #{summary.critical_violations}, Major: #{summary.major_violations}, Minor: #{summary.minor_violations})"
    )

    IO.puts("Warnings: #{summary.total_warnings}")

    if summary.critical_violations > 0 do
      IO.puts("\n🔴 Critical Violations:")

      validation.violations
      |> Enum.filter(&(&1.severity == :critical))
      |> Enum.take(5)
      |> Enum.each(fn violation ->
        IO.puts("  • #{violation.description}")
      end)
    end

    if length(validation.recommendations) > 0 do
      IO.puts("\n💡 Recommendations:")

      validation.recommendations
      |> Enum.take(3)
      |> Enum.each(fn rec ->
        IO.puts("  • #{rec}")
      end)
    end
  end

  # Configuration analysis
  defp analyze_configuration(state) do
    IO.puts("\n📊 Configuration Analysis...")

    case generate_binary_config(state.tlvs) do
      {:ok, binary_config} ->
        case ConfigAnalyzer.analyze(binary_config, docsis_version: state.docsis_version) do
          {:ok, analysis} ->
            show_analysis_results(analysis)

          {:error, reason} ->
            IO.puts("❌ Analysis failed: #{reason}")
        end

      {:error, reason} ->
        IO.puts("❌ Failed to generate binary configuration: #{reason}")
    end
  end

  defp show_analysis_results(analysis) do
    IO.puts("Configuration Analysis:")
    IO.puts("=====================")
    IO.puts("Type: #{String.capitalize(to_string(analysis.configuration_type))}")
    IO.puts("Service Tier: #{String.capitalize(to_string(analysis.service_tier))}")
    IO.puts("Summary: #{analysis.summary}")

    perf = analysis.performance_metrics
    IO.puts("\nPerformance:")
    IO.puts("  Service Flows: #{perf.total_service_flows}")
    IO.puts("  QoS Configuration: #{if perf.has_qos_configuration, do: "Yes", else: "No"}")
    IO.puts("  Complexity Score: #{perf.configuration_complexity}")

    if length(analysis.optimization_suggestions) > 0 do
      IO.puts("\n🚀 Optimization Suggestions:")

      analysis.optimization_suggestions
      |> Enum.take(3)
      |> Enum.each(fn suggestion ->
        IO.puts("  • #{suggestion}")
      end)
    end
  end

  # Utility functions
  defp load_configuration(file_path) do
    case Bindocsis.parse_file(file_path, enhanced: true) do
      {:ok, tlvs} -> {:ok, tlvs}
      {:error, reason} -> {:error, reason}
    end
  end

  defp load_template(template_name) do
    templates = %{
      residential: [
        # Downstream Frequency: 591 MHz
        create_simple_tlv(1, "591000000"),
        # Upstream Channel ID: 1
        create_simple_tlv(2, "1"),
        # Network Access Control: Enabled
        create_simple_tlv(3, "1"),
        # Max CPE IP Addresses: 4
        create_simple_tlv(21, "4")
      ],
      business: [
        # Downstream Frequency: 591 MHz
        create_simple_tlv(1, "591000000"),
        # Upstream Channel ID: 1
        create_simple_tlv(2, "1"),
        # Network Access Control: Enabled
        create_simple_tlv(3, "1"),
        # Max CPE IP Addresses: 16
        create_simple_tlv(21, "16"),
        # Privacy Enable: Enabled
        create_simple_tlv(29, "1")
      ],
      basic: [
        # Downstream Frequency: 591 MHz
        create_simple_tlv(1, "591000000"),
        # Upstream Channel ID: 1
        create_simple_tlv(2, "1"),
        # Network Access Control: Enabled
        create_simple_tlv(3, "1")
      ]
    }

    case Map.get(templates, template_name) do
      nil -> {:error, "Unknown template: #{template_name}"}
      tlvs -> {:ok, tlvs}
    end
  end

  defp create_simple_tlv(type, value_str) do
    %{type: type, length: byte_size(value_str), value: value_str}
  end

  defp create_tlv(tlv_type, value_input, docsis_version) do
    case DocsisSpecs.get_tlv_info(tlv_type, docsis_version) do
      {:ok, tlv_info} ->
        case ValueParser.parse_value(tlv_info.value_type, value_input) do
          {:ok, binary_value} ->
            {:ok,
             %{
               type: tlv_type,
               length: byte_size(binary_value),
               value: binary_value
             }}

          {:error, reason} ->
            {:error, reason}
        end

      {:error, _} ->
        # Try to parse as generic value if TLV type unknown
        case ValueParser.parse_value(:auto, value_input) do
          {:ok, binary_value} ->
            {:ok,
             %{
               type: tlv_type,
               length: byte_size(binary_value),
               value: binary_value
             }}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp format_tlv_value(tlv) do
    case Map.get(tlv, :formatted_value) do
      nil ->
        # Fallback formatting
        tlv.value
        |> :binary.bin_to_list()
        |> Enum.map(&Integer.to_string(&1, 16))
        |> Enum.map(&String.pad_leading(&1, 2, "0"))
        |> Enum.join(" ")

      formatted ->
        formatted
    end
  end

  @doc false
  def format_subtlv_value(subtlv) do
    require Logger

    case Map.get(subtlv, :formatted_value) do
      # Case 1: formatted_value is a Map (e.g., SNMP MIB objects with ASN.1 DER encoding)
      formatted when is_map(formatted) ->
        # Support both atom and string keys
        oid = Map.get(formatted, :oid) || Map.get(formatted, "oid")
        type = Map.get(formatted, :type) || Map.get(formatted, "type")
        value = Map.get(formatted, :value) || Map.get(formatted, "value")

        # Normalize the value to a string
        value_str =
          cond do
            is_binary(value) or is_bitstring(value) ->
              # Strip redundant prefixes like "Unknown Type 0xNN: "
              String.replace(to_string(value), ~r/^Unknown Type 0x[0-9A-Fa-f]+: /, "")

            is_integer(value) ->
              Integer.to_string(value)

            is_nil(value) ->
              Logger.debug("SubTLV formatted_value Map has nil value field")
              binary_to_spaced_hex(subtlv.value)

            true ->
              # Unexpected structure - fall back to hex of raw value
              Logger.debug(
                "Unrecognized structured value encountered for SubTLV display: #{inspect(value)}"
              )

              binary_to_spaced_hex(subtlv.value)
          end

        "OID: #{oid}, Type: #{type}, Value: #{value_str}"

      # Case 2: formatted_value is a non-empty string
      formatted when is_binary(formatted) and formatted != "" ->
        formatted

      # Case 3: formatted_value is nil or empty string - fallback to hex
      _ ->
        binary_to_spaced_hex(subtlv.value)
    end
  end

  # Helper to convert binary to uppercase spaced hex (e.g., "01 0A FF")
  @doc false
  def binary_to_spaced_hex(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.map(&String.upcase/1)
    |> Enum.join(" ")
  end

  defp get_tlv_name(type, docsis_version) do
    case DocsisSpecs.get_tlv_info(type, docsis_version) do
      {:ok, tlv_info} -> tlv_info.name
      {:error, _} -> "Unknown TLV #{type}"
    end
  end

  defp generate_binary_config(tlvs) do
    try do
      # Use the shared BinaryGenerator logic so we correctly handle multi-byte
      # length encoding and built-in TLV validation instead of manually
      # constructing <<type, length>> which can raise for length > 255.
      # First, strip enrichment metadata so we only encode basic TLVs.
      basic_tlvs = Bindocsis.TlvEnricher.unenrich_tlvs(tlvs)

      binary_data =
        basic_tlvs
        |> Enum.map(&BinaryGenerator.encode_single_tlv/1)
        |> IO.iodata_to_binary()

      {:ok, binary_data}
    rescue
      e -> {:error, "Failed to generate binary: #{Exception.message(e)}"}
    end
  end

  defp add_to_history(history, action, params) do
    command = %{
      action: action,
      params: params,
      timestamp: DateTime.utc_now()
    }

    # Keep last 50 commands
    [command | history] |> Enum.take(50)
  end

  # Argument parsing helpers
  defp parse_list_args(""), do: []
  defp parse_list_args(" -v"), do: [verbose: true]
  defp parse_list_args(_), do: []

  defp parse_tlv_spec(spec) do
    case String.split(spec, " ", parts: 2) do
      [type_str, value] ->
        case Integer.parse(type_str) do
          {tlv_type, ""} when tlv_type >= 0 and tlv_type <= 255 ->
            {:ok, tlv_type, value}

          _ ->
            {:error, "Invalid TLV type: #{type_str}. Must be 0-255."}
        end

      _ ->
        {:error, "Invalid format. Use: add <type> <value>"}
    end
  end

  defp parse_tlv_reference(ref) do
    trimmed = if is_binary(ref), do: String.trim(ref), else: ""

    case Integer.parse(trimmed) do
      {index, ""} when index >= 0 -> {:ok, index}
      _ -> {:error, "Invalid TLV index: #{ref}"}
    end
  end

  defp parse_move_spec(spec) do
    case String.split(String.trim(spec), " ") do
      [from_str, "to", to_str] ->
        with {from_index, ""} <- Integer.parse(from_str),
             {to_index, ""} <- Integer.parse(to_str) do
          {:ok, from_index, to_index}
        else
          _ -> {:error, "Invalid move format. Use: move <from_index> to <to_index>"}
        end

      _ ->
        {:error, "Invalid move format. Use: move <from_index> to <to_index>"}
    end
  end

  defp parse_save_args(""), do: [format: :binary]

  defp parse_save_args(" " <> args) do
    trimmed = if is_binary(args), do: String.trim(args), else: ""

    case String.split(trimmed, " ") do
      [filename] ->
        [filename: filename, format: :binary]

      [filename, format_str] ->
        format =
          case String.downcase(format_str) do
            "binary" -> :binary
            "json" -> :json
            "yaml" -> :yaml
            _ -> :binary
          end

        [filename: filename, format: format]

      _ ->
        [format: :binary]
    end
  end

  # Placeholder implementations for remaining functions
  defp handle_quit(state) do
    if state.unsaved_changes do
      input = IO.gets("You have unsaved changes. Save before exiting? [y/N]: ")

      case input do
        :eof ->
          IO.puts("\n👋 Goodbye!")
          :ok

        input when is_binary(input) ->
          answer = input |> String.trim() |> String.downcase()

          case answer do
            answer when answer in ["y", "yes"] ->
              case save_configuration(state, []) do
                {:continue, _} ->
                  IO.puts("👋 Goodbye!")
                  :ok
              end

            _ ->
              IO.puts("👋 Goodbye!")
              :ok
          end
      end
    else
      IO.puts("👋 Goodbye!")
      :ok
    end
  end

  defp save_configuration(state, opts) do
    filename = Keyword.get(opts, :filename, state.current_path || "config.cm")
    format = Keyword.get(opts, :format, :binary)

    case generate_and_save_config(state.tlvs, filename, format) do
      :ok ->
        new_state = %{state | unsaved_changes: false, current_path: filename}
        IO.puts("✅ Configuration saved to #{filename}")
        {:continue, new_state}

      {:error, reason} ->
        IO.puts("❌ Error saving: #{reason}")
        {:continue, state}
    end
  end

  defp generate_and_save_config(tlvs, filename, format) do
    case generate_binary_config(tlvs) do
      {:ok, binary_config} ->
        case format do
          :binary ->
            File.write(filename, binary_config)

          :json ->
            case Bindocsis.generate(tlvs, format: :json) do
              {:ok, json_data} -> File.write(filename, json_data)
              {:error, reason} -> {:error, reason}
            end

          :yaml ->
            case Bindocsis.generate(tlvs, format: :yaml) do
              {:ok, yaml_data} -> File.write(filename, yaml_data)
              {:error, reason} -> {:error, reason}
            end
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp load_and_replace_configuration(state, file_path) do
    case load_configuration(file_path) do
      {:ok, tlvs} ->
        new_state = %{state | tlvs: tlvs, current_path: file_path, unsaved_changes: false}
        IO.puts("✅ Loaded #{length(tlvs)} TLVs from #{file_path}")
        show_configuration(new_state)
        {:continue, new_state}

      {:error, reason} ->
        IO.puts("❌ Error loading: #{reason}")
        {:continue, state}
    end
  end

  defp load_template_and_replace(state, template_name) do
    case load_template(template_name) do
      {:ok, tlvs} ->
        new_state = %{state | tlvs: tlvs, current_path: nil, unsaved_changes: true}
        IO.puts("✅ Loaded template: #{template_name}")
        show_configuration(new_state)
        {:continue, new_state}

      {:error, reason} ->
        IO.puts("❌ Error loading template: #{reason}")
        {:continue, state}
    end
  end

  defp undo_last_change(state) do
    case state.history do
      [] ->
        IO.puts("Nothing to undo.")
        {:continue, state}

      [last_command | rest_history] ->
        case undo_command(state, last_command) do
          {:ok, new_state} ->
            final_state = %{new_state | history: rest_history, unsaved_changes: true}
            IO.puts("✅ Undid: #{last_command.action}")
            {:continue, final_state}

          {:error, reason} ->
            IO.puts("❌ Cannot undo: #{reason}")
            {:continue, state}
        end
    end
  end

  defp undo_command(state, %{action: :add_tlv, params: %{tlv: tlv}}) do
    case Enum.find_index(state.tlvs, &(&1.type == tlv.type && &1.value == tlv.value)) do
      nil ->
        {:error, "TLV not found"}

      index ->
        new_tlvs = List.delete_at(state.tlvs, index)
        {:ok, %{state | tlvs: new_tlvs}}
    end
  end

  defp undo_command(state, %{action: :remove_tlv, params: %{index: index, tlv: tlv}}) do
    new_tlvs = List.insert_at(state.tlvs, index, tlv)
    {:ok, %{state | tlvs: new_tlvs}}
  end

  defp undo_command(state, %{action: :edit_tlv, params: %{index: index, old_tlv: old_tlv}}) do
    new_tlvs = List.replace_at(state.tlvs, index, old_tlv)
    {:ok, %{state | tlvs: new_tlvs}}
  end

  defp undo_command(state, %{
         action: :move_tlv,
         params: %{from_index: from_index, to_index: to_index, tlv: tlv}
       }) do
    # Undo by reversing the move: from to_index back to from_index
    new_tlvs =
      state.tlvs
      |> List.delete_at(to_index)
      |> List.insert_at(from_index, tlv)

    {:ok, %{state | tlvs: new_tlvs}}
  end

  defp undo_command(_state, _command) do
    {:error, "Cannot undo this action"}
  end

  defp handle_settings(state, setting) do
    case String.split(setting, " ", parts: 2) do
      ["validation", "on"] ->
        new_state = %{state | validation_enabled: true}
        IO.puts("✅ Validation enabled")
        {:continue, new_state}

      ["validation", "off"] ->
        new_state = %{state | validation_enabled: false}
        IO.puts("✅ Validation disabled")
        {:continue, new_state}

      ["version", version] when version in ["2.0", "3.0", "3.1", "4.0"] ->
        new_state = %{state | docsis_version: version}
        IO.puts("✅ DOCSIS version set to #{version}")
        {:continue, new_state}

      _ ->
        IO.puts("❌ Invalid setting. Available: validation on/off, version <2.0|3.0|3.1|4.0>")
        {:continue, state}
    end
  end

  # SNMP MIB Object support
  defp parse_snmp_spec(spec) do
    # Parse: <oid> <type> <value>
    # Example: 1.3.6.1.4.1.8595.20.17.1.4.0 integer 2
    trimmed = if is_binary(spec), do: String.trim(spec), else: ""

    case String.split(trimmed, " ", parts: 3) do
      [oid_str, type_str, value_str] ->
        with {:ok, oid} <- parse_oid(oid_str),
             {:ok, value_type} <- parse_snmp_type(type_str),
             {:ok, value} <- parse_snmp_value(value_type, value_str) do
          {:ok, oid, value_type, value}
        else
          {:error, reason} -> {:error, reason}
        end

      _ ->
        {:error, "Invalid SNMP format. Use: add snmp <oid> <type> <value>"}
    end
  end

  defp parse_oid(oid_str) do
    # Parse OID string like "1.3.6.1.4.1.8595.20.17.1.4.0"
    try do
      oid =
        oid_str
        |> String.split(".")
        |> Enum.map(&String.to_integer/1)

      {:ok, oid}
    rescue
      _ -> {:error, "Invalid OID format. Use dotted notation like 1.3.6.1.4.1.8595"}
    end
  end

  defp parse_snmp_type(type_str) do
    case String.downcase(type_str) do
      "integer" -> {:ok, :integer}
      "int" -> {:ok, :integer}
      "string" -> {:ok, :string}
      "octetstring" -> {:ok, :string}
      "octet" -> {:ok, :string}
      _ -> {:error, "Unsupported SNMP type: #{type_str}. Use: integer or string"}
    end
  end

  defp parse_snmp_value(:integer, value_str) do
    case Integer.parse(value_str) do
      {int, ""} -> {:ok, int}
      _ -> {:error, "Invalid integer value: #{value_str}"}
    end
  end

  defp parse_snmp_value(:string, value_str) do
    # Remove quotes if present
    cleaned =
      value_str
      |> String.trim()
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")

    {:ok, cleaned}
  end

  defp add_snmp_mib_object(state, oid, value_type, value) do
    case create_snmp_tlv(oid, value_type, value) do
      {:ok, tlv} ->
        new_tlvs = state.tlvs ++ [tlv]

        new_state = %{
          state
          | tlvs: new_tlvs,
            unsaved_changes: true,
            history: add_to_history(state.history, :add_tlv, %{tlv: tlv})
        }

        IO.puts("✅ Added SNMP MIB Object (TLV 11)")
        IO.puts("   OID: #{Enum.join(oid, ".")}")
        IO.puts("   Type: #{String.upcase(to_string(value_type))}")
        IO.puts("   Value: #{inspect(value)}")

        {:continue, new_state}

      {:error, reason} ->
        IO.puts("❌ Error creating SNMP MIB Object: #{reason}")
        {:continue, state}
    end
  end

  defp create_snmp_tlv(oid, value_type, value) do
    # Create SNMP MIB Object TLV (Type 11) with sub-TLV 48 (Object Value)
    # Structure: TLV 11 contains sub-TLV 48 with ASN.1 DER encoded SEQUENCE(OID, VALUE)

    try do
      # Create ASN.1 objects
      oid_object = Bindocsis.Generators.Asn1Generator.create_object(0x06, oid)

      value_object =
        case value_type do
          :integer -> Bindocsis.Generators.Asn1Generator.create_object(0x02, value)
          :string -> Bindocsis.Generators.Asn1Generator.create_object(0x04, value)
        end

      # Create SEQUENCE containing OID and value
      sequence = Bindocsis.Generators.Asn1Generator.create_sequence([oid_object, value_object])

      # Generate binary ASN.1 DER encoding
      {:ok, asn1_binary} = Bindocsis.Generators.Asn1Generator.generate_object(sequence)

      # Create sub-TLV 48 (Object Value)
      subtlv = %{
        name: "Object Value",
        type: 48,
        length: byte_size(asn1_binary),
        value: asn1_binary,
        description: "SNMP MIB object value in ASN.1 DER encoding",
        formatted_value: %{
          type: String.upcase(to_string(value_type)),
          value: value,
          oid: Enum.join(oid, ".")
        },
        value_type: :asn1_der
      }

      # Create parent TLV 11 (SNMP MIB Object)
      # Encode sub-TLV 48 as binary: Type(1) + Length(1) + Value
      subtlv_binary = <<48, subtlv.length>> <> asn1_binary

      tlv = %{
        name: "SNMP MIB Object",
        type: 11,
        length: byte_size(subtlv_binary),
        value: subtlv_binary,
        description: "SNMP MIB object configuration",
        formatted_value: "Compound TLV with 1 sub-TLVs",
        value_type: :compound,
        subtlvs: [subtlv]
      }

      {:ok, tlv}
    rescue
      e -> {:error, "ASN.1 encoding failed: #{Exception.message(e)}"}
    catch
      {:encode_error, reason} -> {:error, reason}
    end
  end
end
