# Interactive CLI Guide

This guide provides a comprehensive overview of the `Bindocsis` interactive command-line interface (CLI) editor. This powerful tool allows you to load, modify, validate, and save DOCSIS and PacketCable MTA configurations in a live, interactive session.

## 🚀 Getting Started

To launch the interactive editor, use the `edit` command:

### Start with an Empty Configuration

To begin with a new, empty configuration:

```bash
./bindocsis edit
```

### Edit an Existing Configuration File

To load and edit an existing DOCSIS configuration file:

```bash
./bindocsis edit path/to/your/config.cm
```

### Start with a Template

You can also start with a pre-defined template for common configurations (e.g., `docsis3.0_basic`, `mta_sip`):

```bash
./bindocsis edit template docsis3.0_basic
```

## 👋 Exiting the Editor

To exit the interactive editor at any time, type one of the following commands and press Enter:

```
quit
exit
```

If you have unsaved changes, the editor will prompt you to save them before exiting:

```
You have unsaved changes. Save before exiting? [y/N]:
```

Type `y` or `yes` to save your changes to the last loaded/saved file (or a specified output file), or `n` or `no` (or just press Enter) to discard changes and exit.

## 📋 Available Commands

Once inside the interactive editor, you'll see a prompt (e.g., `bindocsis-editor>`). You can type commands to manage your configuration. Commands are case-insensitive.

Here's a list of the primary commands:

### `list [options]`

Displays the current configuration's TLVs (Type-Length-Values).

*   **Usage:**
    ```
    list
    list -v   # Show verbose details including raw values
    ```
*   **Description:** Shows a human-readable representation of the TLVs currently in your configuration. Use `-v` for more detailed output, including raw hexadecimal values and additional information.

### `add <tlv_type> [value]`

Adds a new TLV to the configuration.

*   **Usage:**
    ```
    add 3 1                       # Adds TLV 3 (Network Access) with value 1 (enabled)
    add 6 1000000                 # Adds TLV 6 (Max upstream bandwidth) with value 1Mbps (1,000,000 bps)
    add 68 1000                   # Adds TLV 68 (Default Upstream Target Buffer) with value 1000
    ```
*   **Description:** Adds a TLV by its numerical type and optional value. The editor will guide you if the value is missing or requires specific formatting. For complex TLVs with sub-TLVs, the editor will prompt for details.

### `edit <tlv_reference> [new_value]`

Modifies an existing TLV in the configuration.

*   **Usage:**
    ```
    edit 1 95000000               # Edits the first TLV (index 1) to a new value (95 MHz for Downstream Frequency)
    edit 3 0                      # Edits the TLV at index 3 to value 0 (disabled for Network Access)
    ```
*   **Description:** Edits a TLV using its displayed index from the `list` command. If `new_value` is provided, it attempts to update the TLV. If not, the editor will enter an interactive mode to guide you through updating the TLV's value or sub-TLVs.

### `remove <tlv_reference>`

Removes a TLV from the configuration.

*   **Usage:**
    ```
    remove 2                      # Removes the TLV at index 2
    ```
*   **Description:** Removes a TLV based on its index from the `list` command.

### `validate`

Validates the current configuration against DOCSIS compliance rules.

*   **Usage:**
    ```
    validate
    ```
*   **Description:** Checks the current TLV configuration for compliance with the specified DOCSIS version (defaulting to 3.1 or as set by `set docsis_version`). It reports any missing required TLVs, incorrect value formats, or unsupported TLVs for the given version.

### `save [file_path] [format]`

Saves the current configuration to a file.

*   **Usage:**
    ```
    save                          # Saves to the last loaded file or default output file in binary format
    save my_new_config.cm         # Saves to 'my_new_config.cm' in binary format
    save my_config.json json      # Saves to 'my_config.json' in JSON format
    save my_config.yaml yaml      # Saves to 'my_config.yaml' in YAML format
    ```
*   **Description:** Saves the current state of the configuration. You can specify a `file_path` and an optional `format` (`binary`, `json`, `yaml`, `config`, `pretty`). If no `file_path` is given, it attempts to overwrite the loaded file or defaults to `output.cm` if the configuration was started empty.

### `load <file_path>`

Loads a configuration from a file, replacing the current one.

*   **Usage:**
    ```
    load path/to/another_config.cm
    ```
*   **Description:** Discards the current in-memory configuration (after prompting to save if there are unsaved changes) and loads the specified file. The editor automatically detects the file format.

### `template <template_name>`

Loads a predefined template into the editor.

*   **Usage:**
    ```
    template docsis3.1_full
    ```
*   **Description:** Replaces the current configuration with a known good template. This is useful for starting new configurations quickly.

### `undo`

Undoes the last modification (add, edit, or remove).

*   **Usage:**
    ```
    undo
    ```
*   **Description:** Reverts the configuration to its state before the last command that modified TLVs. Supports multiple undo operations.

### `analyze`

Provides a human-readable analysis and summary of the configuration.

*   **Usage:**
    ```
    analyze
    ```
*   **Description:** Offers insights into key parameters, detected bandwidths, and other summary information derived from the TLVs in the configuration.

### `set <setting_name> <value>`

Adjusts editor settings.

*   **Usage:**
    ```
    set docsis_version 3.0          # Sets the DOCSIS version for validation and TLV lookups
    set validation false            # Turns off automatic validation after each change
    set verbose true                # Enables verbose output for certain commands
    ```
*   **Description:** Allows you to change editor-specific settings, such as the target DOCSIS version for validation or the verbosity of output.

## 🔗 Working with Nested TLVs (e.g., Service Flows)

Many DOCSIS configurations involve **compound TLVs**, which are TLVs that contain other TLVs (called sub-TLVs) inside them. Service Flows (Upstream Service Flow TLV 24 and Downstream Service Flow TLV 25) are prime examples of this. The `Bindocsis` interactive editor is designed to guide you through creating and modifying these complex structures.

When you `add` or `edit` a compound TLV, the editor will enter a sub-prompt or provide interactive questions to help you define its nested sub-TLVs.

### Adding a New Service Flow

Let's say you want to add an Upstream Service Flow (TLV 24).

```
bindocsis-editor> add 24
```
The editor will then guide you, prompting for common sub-TLVs. For example:

```
Adding Upstream Service Flow (TLV 24).
Enter Service Flow Reference (TLV 1): 100
Enter Traffic Priority (TLV 56, 0-7): 5
Enter Maximum Sustained Traffic Rate (TLV 6, bps): 20000000
Enter Maximum Transmit Burst (TLV 9, bytes): 16384
Enter Service Flow Scheduling Type (TLV 54, 1-5): 1
Add more sub-TLVs? [y/N]: n
```
After you provide the necessary information, the complete compound TLV will be added to your configuration.

### Editing an Existing Service Flow

To modify a sub-TLV within an existing Service Flow (or any compound TLV), you can use the `edit` command with the index of the compound TLV.

First, use `list` to find the index of the Service Flow you want to edit:

```
bindocsis-editor> list
...
1. TLV 24: Upstream Service Flow (SFID: 100)
   SubTLVs:
     TLV 1: Service Flow Reference = 100
     TLV 56: Traffic Priority = 5
     TLV 6: Max Sustained Traffic Rate = 20000000 bps
...
```
Then, use `edit` with its index. If you provide no new value, the editor will guide you:

```
bindocsis-editor> edit 1
```
The editor will display the current sub-TLVs and ask which one you'd like to modify or add:

```
Editing Upstream Service Flow (TLV 24) at index 1.
Current Sub-TLVs:
  0. TLV 1: Service Flow Reference (100)
  1. TLV 56: Traffic Priority (5)
  2. TLV 6: Max Sustained Traffic Rate (20000000 bps)

Enter sub-TLV index to edit (e.g., '1' for Traffic Priority) or 'add <type>' to add a new sub-TLV: 1
```
If you enter `1` (for Traffic Priority), it will then prompt for the new value:

```
Editing Traffic Priority (TLV 56). Current value: 5
Enter new value (0-7): 7
```
This interactive flow allows precise modifications to complex nested structures without needing to reconstruct the entire TLV.

## 💡 Tips and Tricks

*   **Tab Completion:** (Future Feature) Auto-completion for commands and TLV types.
*   **Command History:** (Future Feature) Use arrow keys to navigate through previously entered commands.
*   **Help:** While in the editor, typing `help` (or an unrecognized command) will display a summary of available commands.
*   **Error Messages:** Pay attention to error messages; they usually provide hints on correct usage or validation issues.

This guide will be expanded with more detailed examples and advanced usage scenarios.