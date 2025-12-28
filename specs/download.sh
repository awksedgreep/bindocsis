#!/bin/bash

# Directory to save downloads
mkdir -p packetcable_specs
cd packetcable_specs

# List of key non-deprecated PacketCable specs (PDF downloads)
urls=(
  "https://account.cablelabs.com/server/alfresco/6627e0be-02a5-4359-ada7-a649ea9d851d"  # PKT-SP-PROV1.5 (MTA Device Provisioning)
  "https://account.cablelabs.com/server/alfresco/f04ba198-29bb-4f9c-a1a8-7eb2f2d2acd3"  # PKT-SP-SEC1.5 (Security)
  "https://account.cablelabs.com/server/alfresco/9798cc6e-2274-4736-9b3a-9ddbf1a1e756"  # PKT-SP-DQOS1.5 (Dynamic QoS)
  "https://account.cablelabs.com/server/alfresco/36ca40af-121b-4234-93c2-3a2437532332"  # PKT-SP-EM1.5 (Event Messages)
  "https://account.cablelabs.com/server/alfresco/2ad5f3d8-237e-4fbd-a249-baa5ee600827"  # PKT-SP-CODEC1.5 (Audio/Video Codecs)
  "https://account.cablelabs.com/server/alfresco/152f0820-cf0c-4a23-ada3-898746e490c2"  # PKT-SP-MM (Multimedia)
  "https://account.cablelabs.com/server/alfresco/5617a6eb-8570-4163-8db4-11e362e2af5c"   # MIBs Framework
)

echo "Downloading PacketCable specifications..."
for url in "${urls[@]}"; do
  wget --content-disposition "$url"
done

echo "Download complete. Files saved in $(pwd)"
