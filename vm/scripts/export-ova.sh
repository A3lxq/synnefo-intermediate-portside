#!/usr/bin/env bash
# export-ova.sh — builds a standard OVF/OVA appliance from the already-
# exported standalone qcow2 (run export-vm.sh first). OVA is a cross-
# vendor DMTF standard; VirtualBox, VMware Workstation/Fusion, and ESXi
# all import it. Built directly with qemu-img + a hand-written OVF
# descriptor -- no VirtualBox/VMware needed on the build host.
set -euo pipefail
cd "$(dirname "$0")/.."

SRC_QCOW2="dist/intermediate-portside-ctf.qcow2"
OUT_DIR="dist"
VM_NAME="intermediate-portside-ctf"
VMDK="$OUT_DIR/$VM_NAME-disk001.vmdk"
OVF="$OUT_DIR/$VM_NAME.ovf"
MF="$OUT_DIR/$VM_NAME.mf"
OVA="$OUT_DIR/$VM_NAME.ova"
MEM_MB=1024
CPUS=2

if [ ! -f "$SRC_QCOW2" ]; then
  echo "Missing $SRC_QCOW2. Run ./scripts/export-vm.sh first." >&2
  exit 1
fi

echo "== Converting qcow2 -> stream-optimized VMDK (OVF-required subformat) =="
rm -f "$VMDK"
qemu-img convert -p -O vmdk -o subformat=streamOptimized "$SRC_QCOW2" "$VMDK"

VMDK_SIZE=$(stat -c %s "$VMDK")
CAPACITY_BYTES=$(qemu-img info --output=json "$SRC_QCOW2" | python3 -c 'import json,sys; print(json.load(sys.stdin)["virtual-size"])')
POPULATED_SIZE="$VMDK_SIZE"

echo "== Writing OVF descriptor =="
cat > "$OVF" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Envelope vmw:buildId="build-$VM_NAME" xmlns="http://schemas.dmtf.org/ovf/envelope/1" xmlns:cim="http://schemas.dmtf.org/wbem/wscim/1/common" xmlns:ovf="http://schemas.dmtf.org/ovf/envelope/1" xmlns:rasd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_ResourceAllocationSettingData" xmlns:vmw="http://www.vmware.com/schema/ovf" xmlns:vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
  <References>
    <File ovf:href="$(basename "$VMDK")" ovf:id="file1" ovf:size="$VMDK_SIZE"/>
  </References>
  <DiskSection>
    <Info>Virtual disk information</Info>
    <Disk ovf:capacity="$CAPACITY_BYTES" ovf:capacityAllocationUnits="byte" ovf:diskId="vmdisk1" ovf:fileRef="file1" ovf:format="http://www.vmware.com/interfaces/specifications/vmdk.html#streamOptimized" ovf:populatedSize="$POPULATED_SIZE"/>
  </DiskSection>
  <NetworkSection>
    <Info>The list of logical networks</Info>
    <Network ovf:name="NAT">
      <Description>Host-only / NAT network for the isolated CTF lab. Do not bridge this to a public network.</Description>
    </Network>
  </NetworkSection>
  <VirtualSystem ovf:id="$VM_NAME">
    <Info>Case File 3 (Intermediate) -- Portside -- Halcyon Protocol CTF VM (Ubuntu Server 24.04 LTS, Docker-in-VM)</Info>
    <Name>$VM_NAME</Name>
    <OperatingSystemSection ovf:id="101" ovf:version="24.04" vmw:osType="ubuntu64Guest">
      <Info>The kind of installed guest operating system</Info>
      <Description>Ubuntu Linux (64-bit)</Description>
    </OperatingSystemSection>
    <VirtualHardwareSection>
      <Info>Virtual hardware requirements</Info>
      <System>
        <vssd:ElementName>Virtual Hardware Family</vssd:ElementName>
        <vssd:InstanceID>0</vssd:InstanceID>
        <vssd:VirtualSystemIdentifier>$VM_NAME</vssd:VirtualSystemIdentifier>
        <vssd:VirtualSystemType>vmx-19</vssd:VirtualSystemType>
      </System>
      <Item>
        <rasd:AllocationUnits>hertz * 10^6</rasd:AllocationUnits>
        <rasd:Description>Number of virtual CPUs</rasd:Description>
        <rasd:ElementName>$CPUS virtual CPU(s)</rasd:ElementName>
        <rasd:InstanceID>1</rasd:InstanceID>
        <rasd:ResourceType>3</rasd:ResourceType>
        <rasd:VirtualQuantity>$CPUS</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:AllocationUnits>byte * 2^20</rasd:AllocationUnits>
        <rasd:Description>Memory Size</rasd:Description>
        <rasd:ElementName>${MEM_MB}MB of memory</rasd:ElementName>
        <rasd:InstanceID>2</rasd:InstanceID>
        <rasd:ResourceType>4</rasd:ResourceType>
        <rasd:VirtualQuantity>$MEM_MB</rasd:VirtualQuantity>
      </Item>
      <Item>
        <rasd:Address>0</rasd:Address>
        <rasd:Description>IDE Controller</rasd:Description>
        <rasd:ElementName>IDE Controller 0</rasd:ElementName>
        <rasd:InstanceID>3</rasd:InstanceID>
        <rasd:ResourceSubType>PIIX4</rasd:ResourceSubType>
        <rasd:ResourceType>5</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:AddressOnParent>0</rasd:AddressOnParent>
        <rasd:ElementName>Hard Disk 1</rasd:ElementName>
        <rasd:HostResource>ovf:/disk/vmdisk1</rasd:HostResource>
        <rasd:InstanceID>4</rasd:InstanceID>
        <rasd:Parent>3</rasd:Parent>
        <rasd:ResourceType>17</rasd:ResourceType>
      </Item>
      <Item>
        <rasd:AddressOnParent>7</rasd:AddressOnParent>
        <rasd:AutomaticAllocation>true</rasd:AutomaticAllocation>
        <rasd:Connection>NAT</rasd:Connection>
        <rasd:Description>E1000 ethernet adapter -- host-only NAT</rasd:Description>
        <rasd:ElementName>Network adapter 1</rasd:ElementName>
        <rasd:InstanceID>5</rasd:InstanceID>
        <rasd:ResourceSubType>E1000</rasd:ResourceSubType>
        <rasd:ResourceType>10</rasd:ResourceType>
      </Item>
    </VirtualHardwareSection>
    <AnnotationSection>
      <Info>A description of the meaning of the VM</Info>
      <Annotation>Case File 3 (Intermediate) -- Portside -- Halcyon Protocol CTF VM. Deliberately
vulnerable -- isolated lab use only. Never expose this appliance's
network adapter to a public or shared network. The box (docker-compose,
inside this VM) starts itself automatically on boot and generates its
own fresh per-deployment secret the first time it runs -- no setup
needed beyond powering the VM on. See the accompanying repo's README
and STORY.md.</Annotation>
    </AnnotationSection>
  </VirtualSystem>
</Envelope>
EOF

echo "== Validating the OVF XML is well-formed =="
python3 -c "import xml.etree.ElementTree as ET; ET.parse('$OVF')" && echo "XML OK"

echo "== Writing the manifest (.mf) =="
OVF_HASH=$(sha256sum "$OVF" | cut -d' ' -f1)
VMDK_HASH=$(sha256sum "$VMDK" | cut -d' ' -f1)
cat > "$MF" <<EOF
SHA256($(basename "$OVF"))= $OVF_HASH
SHA256($(basename "$VMDK"))= $VMDK_HASH
EOF

echo "== Packing the .ova (uncompressed tar, OVF file first per spec) =="
rm -f "$OVA"
tar -C "$OUT_DIR" -cf "$OVA" "$(basename "$OVF")" "$(basename "$MF")" "$(basename "$VMDK")"

echo "== Structural self-check =="
tar -tvf "$OVA"
( cd "$OUT_DIR" && sha256sum -c "$(basename "$MF")" )

echo
echo "Built: $OVA ($(du -h "$OVA" | cut -f1))"

if command -v VBoxManage >/dev/null 2>&1; then
  echo
  echo "== VBoxManage found -- running a real dry-run import validation =="
  VBoxManage import "$OVA" --dry-run
  echo "VBoxManage accepted the appliance (dry-run, no VM actually created)."
else
  echo
  echo "VBoxManage not found on this host -- this .ova has only been"
  echo "structurally validated (XML, tar layout, manifest checksums)."
  echo "Before trusting it for an event, test with:"
  echo "  VBoxManage import $OVA --dry-run"
  echo "or VMware Workstation/Fusion's File > Open on the .ova."
fi

rm -f "$VMDK" "$OVF" "$MF"
echo
echo "Cleaned up intermediate files -- their contents are inside $OVA."
