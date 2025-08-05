defmodule Bindocsis.Test.Fixtures do
  @moduledoc """
  Test fixture helpers for Bindocsis tests.
  
  Provides utilities to access test fixtures and problematic binaries
  for reproducing parsing issues and testing edge cases.
  """

  @doc """
  Returns the binary data for the service flow that produces TLVs 0, 9, 24.
  
  This binary is used to reproduce the issue where the binary parser
  incorrectly creates spurious TLV 0 and TLV 9 when parsing service flow
  compound TLVs. 
  
  According to the issue analysis:
  - The binary should contain only TLV 24/25 (service flows)
  - But the parser incorrectly outputs TLV 0, 9, 24
  - TLV 0 is created with invalid 2-byte length instead of required 1-byte
  
  ## Returns
  
      binary() - The problematic service flow binary data
  
  ## Examples
  
      iex> binary = Bindocsis.Test.Fixtures.bad_service_flow()
      iex> {:ok, tlvs} = Bindocsis.parse(binary, format: :binary)
      iex> tlv_types = Enum.map(tlvs, & &1.type) |> Enum.sort()
      [0, 9, 24]  # Should demonstrate the parsing issue
  """
  @spec bad_service_flow() :: binary()
  def bad_service_flow do
    # Read the fixture file that reproduces the TLV 0, 9, 24 issue
    fixture_path = Path.join([__DIR__, "..", "fixtures", "bad_service_flow.bin"])
    File.read!(fixture_path)
  end

  @doc """
  Returns the path to the bad service flow fixture file.
  
  Useful for tests that need to work with the file directly.
  
  ## Returns
  
      String.t() - Path to the bad_service_flow.bin fixture file
  """
  @spec bad_service_flow_path() :: String.t()
  def bad_service_flow_path do
    Path.join([__DIR__, "..", "fixtures", "bad_service_flow.bin"])
  end

  @doc """
  Verifies that the bad service flow binary reproduces the expected issue.
  
  This function can be used in tests to confirm that the fixture still
  demonstrates the problematic parsing behavior.
  
  ## Returns
  
      boolean() - true if the binary produces TLVs 0, 9, 24; false otherwise
  """
  @spec reproduces_tlv_issue?() :: boolean()
  def reproduces_tlv_issue? do
    binary = bad_service_flow()
    
    case Bindocsis.parse(binary, format: :binary) do
      {:ok, tlvs} ->
        tlv_types = tlvs |> Enum.map(&(&1.type)) |> Enum.sort()
        Enum.sort([0, 9, 24]) == tlv_types
        
      {:error, _} ->
        false
    end
  rescue
    _ -> false
  end
end
