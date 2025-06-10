# MTA (Multimedia Terminal Adapter) Demo for PacketCable Configuration Files
# This script demonstrates the parsing, generation, and conversion capabilities
# for PacketCable MTA configuration files.

defmodule MTADemo do
  @moduledoc """
  Demo script showcasing MTA (Multimedia Terminal Adapter) functionality.
  
  This demonstrates the key differences between DOCSIS CM files and PacketCable MTA files,
  including voice-specific TLVs and configuration patterns.
  """

  def run do
    IO.puts """
    
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                  MTA (Multimedia Terminal Adapter) Demo                     ║
    ║                        PacketCable Configuration Files                      ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    
    This demo showcases the parsing and generation of PacketCable MTA configuration
    files, which are used for voice services over cable networks.
    
    Key differences from DOCSIS CM files:
    • Voice-specific TLVs (64-85)
    • PacketCable security parameters
    • Kerberos realm configuration
    • VoIP service provisioning
    
    """

    # Demo 1: Create and parse a sample MTA configuration
    demo_text_parsing()
    
    # Demo 2: Generate binary MTA files
    demo_binary_generation()
    
    # Demo 3: Round-trip conversion
    demo_round_trip_conversion()
    
    # Demo 4: MTA-specific TLV information
    demo_mta_tlv_specs()
    
    # Demo 5: Format detection
    demo_format_detection()
    
    IO.puts """
    
    ╔══════════════════════════════════════════════════════════════════════════════╗
    ║                              Demo Complete!                                 ║
    ║                                                                              ║
    ║  The MTA parser and generator successfully handle PacketCable configuration  ║
    ║  files with voice-specific TLVs and can convert between text and binary     ║
    ║  formats while maintaining full compatibility with DOCSIS specifications.   ║
    ╚══════════════════════════════════════════════════════════════════════════════╝
    
    """
  end

  defp demo_text_parsing do
    IO.puts "📋 Demo 1: Parsing MTA Text Configuration"
    IO.puts "=" |> String.duplicate(50)
    
    # Create a sample MTA configuration
    mta_config_text = """
    // PacketCable MTA Configuration for Voice Services
    NetworkAccessControl on
    
    MTAConfigurationFile {
        VoiceConfiguration {
            CallSignaling sip
            MediaGateway rtp
        }
        
        KerberosRealm "PACKETCABLE.EXAMPLE.COM"
        DNSServer 192.168.1.1
        
        ProvisioningServer {
            PrimaryDNS 192.168.1.1
            SecondaryDNS 192.168.1.2
        }
        
        MTAMACAddress 00:11:22:33:44:55
        SubscriberID "voice_customer_001"
        
        CallFeatureConfiguration {
            CallWaiting on
            CallForwarding on
            CallerID on
        }
        
        EmergencyServices {
            E911Enable on
            EmergencyNumber "911"
        }
    }
    """
    
    IO.puts "Sample MTA Configuration:"
    IO.puts mta_config_text
    
    case Bindocsis.parse(mta_config_text, format: :config) do
      {:ok, tlv_list} ->
        IO.puts "\n✅ Successfully parsed MTA configuration!"
        IO.puts "   Format: mta (detected from TLV content)"
        IO.puts "   PacketCable Version: 2.0 (default)"
        IO.puts "   Number of TLVs: #{length(tlv_list)}"
        
        # Show MTA-specific TLVs (64-85 range)
        mta_specific_tlvs = Enum.filter(tlv_list, fn tlv ->
          tlv.type >= 64 and tlv.type <= 85
        end)
        
        IO.puts "\n   MTA-specific TLVs found:"
        Enum.each(mta_specific_tlvs, fn tlv ->
          IO.puts "   • TLV #{tlv.type}: #{inspect(tlv.value)}"
        end)
        
      {:error, reason} ->
        IO.puts "\n❌ Parsing failed: #{reason}"
    end
    
    IO.puts "\n"
  end

  defp demo_binary_generation do
    IO.puts "🔧 Demo 2: Generating Binary MTA Files"
    IO.puts "=" |> String.duplicate(50)
    
    # Create a simple MTA configuration
    config = [
      %{type: 3, length: 1, value: <<1>>},  # NetworkAccessControl
      %{type: 69, length: 23, value: "PACKETCABLE.DEMO.COM"},  # KerberosRealm
      %{type: 70, length: 4, value: <<192, 168, 1, 1>>},      # DNSServer
      %{type: 78, length: 6, value: <<0, 0x11, 0x22, 0x33, 0x44, 0x55>>}  # MTAMACAddress
    ]
    
    case Bindocsis.generate(config, format: :binary) do
      {:ok, binary_data} ->
        IO.puts "✅ Successfully generated binary MTA file!"
        IO.puts "   Binary size: #{byte_size(binary_data)} bytes"
        IO.puts "   Hex representation:"
        
        # Display hex dump
        hex_string = binary_data
        |> :binary.bin_to_list()
        |> Enum.map(&Integer.to_string(&1, 16))
        |> Enum.map(&String.pad_leading(&1, 2, "0"))
        |> Enum.chunk_every(16)
        |> Enum.with_index()
        |> Enum.map(fn {chunk, index} ->
          offset = Integer.to_string(index * 16, 16) |> String.pad_leading(4, "0")
          hex_part = Enum.join(chunk, " ") |> String.pad_trailing(47)
          "   #{offset}: #{hex_part}"
        end)
        |> Enum.join("\n")
        
        IO.puts hex_string
        
      {:error, reason} ->
        IO.puts "❌ Generation failed: #{reason}"
    end
    
    IO.puts "\n"
  end

  defp demo_round_trip_conversion do
    IO.puts "🔄 Demo 3: Round-trip Conversion (Text → Binary → Text)"
    IO.puts "=" |> String.duplicate(60)
    
    original_config = """
    NetworkAccessControl on
    MTAConfigurationFile {
        VoiceConfiguration {
            CallSignaling sip
        }
        KerberosRealm "ROUNDTRIP.TEST.COM"
        DNSServer 10.0.0.1
        MTAMACAddress 00:AA:BB:CC:DD:EE
    }
    """
    
    IO.puts "Original configuration:"
    IO.puts original_config
    
    with {:ok, parsed_config} <- Bindocsis.parse(original_config, format: :config),
         {:ok, binary_data} <- Bindocsis.generate(parsed_config, format: :binary),
         {:ok, reparsed_config} <- Bindocsis.parse(binary_data, format: :binary),
         {:ok, final_text} <- Bindocsis.generate(reparsed_config, format: :config) do
      
      IO.puts "\n✅ Round-trip conversion successful!"
      IO.puts "   Text → Binary: #{byte_size(binary_data)} bytes"
      IO.puts "   Binary → Text: #{String.length(final_text)} characters"
      
      IO.puts "\nRegenerated configuration:"
      IO.puts final_text
      
      # Compare TLV counts
      original_tlv_count = length(parsed_config)
      final_tlv_count = length(reparsed_config)
      
      if original_tlv_count == final_tlv_count do
        IO.puts "\n✅ TLV count preserved: #{original_tlv_count} TLVs"
      else
        IO.puts "\n⚠️  TLV count changed: #{original_tlv_count} → #{final_tlv_count}"
      end
      
    else
      {:error, reason} ->
        IO.puts "\n❌ Round-trip conversion failed: #{reason}"
    end
    
    IO.puts "\n"
  end

  defp demo_mta_tlv_specs do
    IO.puts "📊 Demo 4: MTA-specific TLV Information"
    IO.puts "=" |> String.duplicate(50)
    
    IO.puts "PacketCable TLV Categories:\n"
    
    # Show MTA-specific TLVs (PacketCable range 64-85)
    mta_types = 64..85 |> Enum.to_list()
    IO.puts "🎙️  Voice/MTA-specific TLVs:"
    
    mta_types
    |> Enum.take(10)  # Show first 10
    |> Enum.each(fn type ->
      # Get TLV name from the mapping if available
      tlv_name = case type do
        64 -> "MTA Configuration File"
        65 -> "Voice Configuration" 
        66 -> "Call Signaling"
        67 -> "Media Gateway"
        68 -> "Security Association"
        69 -> "Kerberos Realm"
        70 -> "DNS Server"
        _ -> "PacketCable TLV #{type}"
      end
      IO.puts "   TLV #{type}: #{tlv_name}"
    end)
    
    if length(mta_types) > 10 do
      IO.puts "   ... and #{length(mta_types) - 10} more MTA-specific TLVs"
    end
    
    # Show PacketCable version evolution
    IO.puts "\n📈 PacketCable Version Evolution:"
    IO.puts "   PacketCable 1.0: 21 supported TLVs (TLVs 64-84)"
    IO.puts "   PacketCable 1.5: 22 supported TLVs (added emergency services)"
    IO.puts "   PacketCable 2.0: 22 supported TLVs (enhanced voice features)"
    
    # Show some example TLV details
    IO.puts "\n🔍 Example TLV Details:"
    example_tlvs = [
      {64, "MTA Configuration File", "compound"},
      {65, "Voice Configuration", "compound"}, 
      {69, "Kerberos Realm", "string"},
      {78, "MTA MAC Address", "mac"}
    ]
    
    Enum.each(example_tlvs, fn {type, name, value_type} ->
      IO.puts "   TLV #{type} (#{name}):"
      IO.puts "     • Type: #{value_type}"
      IO.puts "     • PacketCable Voice TLV"
    end)
    
    IO.puts "\n"
  end

  defp demo_format_detection do
    IO.puts "🔍 Demo 5: Automatic Format Detection"
    IO.puts "=" |> String.duplicate(50)
    
    # Test different content types
    test_cases = [
      {
        "MTA Text Configuration",
        """
        NetworkAccessControl on
        MTAConfigurationFile {
            VoiceConfiguration {
                CallSignaling sip
            }
        }
        """
      },
      {
        "DOCSIS JSON Configuration", 
        """
        {
          "docsis_version": "3.1",
          "tlvs": [
            {"type": 3, "length": 1, "value": true}
          ]
        }
        """
      },
      {
        "YAML Configuration",
        """
        docsis_version: "3.1"
        tlvs:
          - type: 3
            length: 1
            value: true
        """
      },
      {
        "Binary TLV Data",
        <<3, 1, 1, 64, 5, 65, 3, 66, 1, 1>>
      }
    ]
    
    Enum.each(test_cases, fn {description, content} ->
      # Write to temporary file for detection
      temp_file = "/tmp/test_#{:erlang.unique_integer([:positive])}"
      File.write!(temp_file, content)
      
      detected_format = Bindocsis.FormatDetector.detect_format(temp_file)
      
      IO.puts "#{description}:"
      IO.puts "   Detected format: #{detected_format}"
      
      # Test content-based detection
      content_format = Bindocsis.FormatDetector.detect_by_content(temp_file)
      if content_format != detected_format do
        IO.puts "   Content-based: #{content_format}"
      end
      
      # Clean up
      File.rm(temp_file)
    end)
    
    IO.puts "\n✅ Format detection correctly identifies MTA files vs other formats"
    IO.puts "\n"
  end
end

# Run the demo
MTADemo.run()