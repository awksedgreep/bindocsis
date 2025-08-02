[
  # False positive warnings for pattern matching in with statements
  # These functions work correctly but dialyzer is being overly conservative
  ~r/lib\/bindocsis\/human_config\.ex:93.*pattern_match/,
  ~r/lib\/bindocsis\/human_config\.ex:108.*pattern_match/,
  ~r/lib\/bindocsis\/human_config\.ex:196.*pattern_match/,
  ~r/lib\/bindocsis\/parsers\/mta_binary_parser\.ex:55.*pattern_match/
]
