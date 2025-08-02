#!/usr/bin/env elixir

# Read the original file and modify specific byte sequences that likely represent bandwidth
{:ok, original_binary} = File.read("17HarvestMoonCW.cm")

IO.puts("Original file size: #{byte_size(original_binary)} bytes")

# For this type of modification, I'll create a simple change:
# Look for large 32-bit values that might represent bandwidth in bps and modify them

# 75 Mbps = 75 * 1024 * 1024 = 78,643,200 bps (0x04B0_0000)
# But for simplicity, let's use 75,000,000 bps (0x047A_E540)
new_bandwidth = 75_000_000

# Convert to binary (big-endian, 4 bytes)
new_bandwidth_binary = <<new_bandwidth::32>>

IO.puts("New bandwidth: #{new_bandwidth} bps")
IO.puts("New bandwidth binary: #{inspect(new_bandwidth_binary)}")

# Let's examine some existing large values in the file to understand the format
<<_prefix::binary-size(50), sample_bytes::binary-size(20), _rest::binary>> = original_binary
IO.puts("Sample bytes from position 50: #{inspect(sample_bytes)}")

# For now, let's create a modified version by replacing some specific sequences
# that look like they might be bandwidth-related

# Looking at the hex dump from earlier:
# Type 24 (upstream) has: 8, 4, 3, 71, 59, 192 which could be 0x03475BC0 = 55,000,000
# Type 25 (downstream) has: 8, 4, 5, 245, 225, 0 which could be 0x05F5E100 = 100,000,000

# Let's replace these specific 4-byte sequences
old_upstream_pattern = <<3, 71, 59, 192>>    # 55,000,000
old_downstream_pattern = <<5, 245, 225, 0>>  # 100,000,000

new_upstream_pattern = <<4, 122, 229, 64>>   # 75,000,000

IO.puts("Looking for upstream pattern: #{inspect(old_upstream_pattern)}")
IO.puts("Will replace with: #{inspect(new_upstream_pattern)}")

# Replace the pattern
modified_binary = case :binary.split(original_binary, old_upstream_pattern) do
  [prefix, suffix] ->
    IO.puts("Found upstream pattern, replacing...")
    prefix <> new_upstream_pattern <> suffix
  [_] ->
    IO.puts("Upstream pattern not found, keeping original")
    original_binary
end

# Write the modified file
File.write!("17HarvestMoonCW100x75.cm", modified_binary)

IO.puts("✅ Created modified file: 17HarvestMoonCW100x75.cm")
IO.puts("📊 New file size: #{byte_size(modified_binary)} bytes")

# Verify the new file can be parsed
IO.puts("🔍 Verifying new file...")
case Bindocsis.parse_file("17HarvestMoonCW100x75.cm") do
  {:ok, verified_tlvs} ->
    IO.puts("✅ Verification successful! Parsed #{length(verified_tlvs)} TLVs")
  {:error, reason} ->
    IO.puts("❌ Verification failed: #{reason}")
end

# Show the difference
if modified_binary != original_binary do
  IO.puts("✅ File was modified successfully")
else
  IO.puts("⚠️  File was not modified (pattern not found)")
end