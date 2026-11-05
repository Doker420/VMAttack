from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from xml.sax.saxutils import escape
import hashlib
import xml.etree.ElementTree as ET
import zipfile

PROJECT = Path(__file__).resolve().parents[1]
REPOSITORY = PROJECT.parent
SRC = PROJECT / "src"
PLACE = PROJECT / "SwapPlaces.rbxlx"
BUNDLE = REPOSITORY / "SwapPlaces-Complete.zip"


@dataclass
class Node:
    class_name: str
    name: str
    source: str | None = None
    properties: list[str] = field(default_factory=list)
    children: list["Node"] = field(default_factory=list)


def module(name: str, relative: str) -> Node:
    return Node("ModuleScript", name, (SRC / relative).read_text(encoding="utf-8"))


def script(name: str, relative: str, local: bool = False) -> Node:
    properties = [] if local else ['<token name="RunContext">0</token>']
    return Node("LocalScript" if local else "Script", name, (SRC / relative).read_text(encoding="utf-8"), properties)


def build_tree() -> Node:
    # A synthetic root is serialized as the six service siblings required by a place.
    return Node(
        "DataModel",
        "SwapPlaces",
        children=[
            Node("Lighting", "Lighting"),
            Node("Players", "Players", properties=['<bool name="CharacterAutoLoads">true</bool>']),
            Node(
                "ReplicatedStorage",
                "ReplicatedStorage",
                children=[Node("Folder", "SwapPlaces", children=[
                    module("Config", "ReplicatedStorage/Config.lua"),
                    module("SkinCatalog", "ReplicatedStorage/SkinCatalog.lua"),
                ])],
            ),
            Node(
                "ServerScriptService",
                "ServerScriptService",
                children=[Node("Folder", "SwapPlacesServer", children=[
                    script("Main", "ServerScriptService/Main.server.lua"),
                    Node("Folder", "Services", children=[
                        module(path.stem, f"ServerScriptService/Services/{path.name}")
                        for path in sorted((SRC / "ServerScriptService" / "Services").glob("*.lua"))
                    ]),
                ])],
            ),
            Node(
                "StarterPlayer",
                "StarterPlayer",
                children=[Node("StarterPlayerScripts", "StarterPlayerScripts", children=[
                    script("Client", "StarterPlayer/StarterPlayerScripts/Client.client.lua", local=True),
                ])],
            ),
            Node("Workspace", "Workspace", properties=['<bool name="NeedsPivotMigration">false</bool>']),
        ],
    )


def serialize(root: Node) -> str:
    referent = 0

    def emit(node: Node, indent: int = 2) -> str:
        nonlocal referent
        own_ref = referent
        referent += 1
        pad = " " * indent
        lines = [f'{pad}<Item class="{node.class_name}" referent="{own_ref}">', f"{pad}  <Properties>"]
        lines.append(f'{pad}    <string name="Name">{escape(node.name)}</string>')
        lines.extend(f"{pad}    {prop}" for prop in node.properties)
        if node.source is not None:
            if "]] >".replace(" ", "") in node.source:
                raise RuntimeError(f"CDATA terminator in {node.name}")
            lines.append(f'{pad}    <string name="Source"><![CDATA[{node.source}]]></string>')
        lines.append(f"{pad}  </Properties>")
        for child in node.children:
            lines.append(emit(child, indent + 2))
        lines.append(f"{pad}</Item>")
        return "\n".join(lines)

    body = "\n".join(emit(child) for child in root.children)
    return f'<roblox version="4">\n{body}\n</roblox>\n'


def expected_sources() -> dict[str, str]:
    result = {}
    for path in sorted(SRC.rglob("*.lua")):
        relative = path.relative_to(SRC).as_posix()
        name = path.name[:-4]
        if name.endswith(".server"):
            name = name[:-7]
        elif name.endswith(".client"):
            name = name[:-7]
        if relative.startswith("ReplicatedStorage/"):
            tail = relative[len("ReplicatedStorage/"):]
            key = "ReplicatedStorage/SwapPlaces/" + (tail[:-4] if tail.endswith(".lua") else tail)
        elif relative.startswith("ServerScriptService/"):
            tail = relative[len("ServerScriptService/"):]
            key = "ServerScriptService/SwapPlacesServer/" + str(Path(tail).with_suffix("")).replace("\\", "/")
        else:
            key = "StarterPlayer/StarterPlayerScripts/" + name
        # Normalize suffix-bearing Main/Client names while preserving service paths.
        key = key.replace("Main.server", "Main").replace("Client.client", "Client")
        result[key] = path.read_text(encoding="utf-8")
    return result


def audit_place() -> None:
    root = ET.parse(PLACE).getroot()
    actual = {}

    def walk(item: ET.Element, parents: tuple[str, ...]) -> None:
        props = item.find("Properties")
        name = None
        source = None
        for prop in props or []:
            if prop.attrib.get("name") == "Name":
                name = prop.text or ""
            elif prop.attrib.get("name") == "Source":
                source = prop.text or ""
        if name is None:
            raise RuntimeError(f"Missing Name on {item.attrib.get('class')}")
        path = parents + (name,)
        if item.attrib.get("class") in ("Script", "LocalScript", "ModuleScript"):
            key = "/".join(path)
            if key in actual:
                raise RuntimeError(f"Duplicate XML script path: {key}")
            actual[key] = source or ""
        for child in item.findall("Item"):
            walk(child, path)

    for service in root.findall("Item"):
        walk(service, ())
    expected = expected_sources()
    if actual != expected:
        raise RuntimeError(f"Source parity failed: missing={sorted(set(expected)-set(actual))}, extra={sorted(set(actual)-set(expected))}, changed={[key for key in expected.keys() & actual.keys() if expected[key] != actual[key]]}")
    print(f"XML_PARITY=PASS scripts={len(expected)} structuralPaths=PASS")


def package() -> None:
    excluded = {"__pycache__", ".pytest_cache"}
    files = sorted(
        path for path in PROJECT.rglob("*")
        if path.is_file() and path.suffix != ".pyc" and not any(part in excluded for part in path.parts)
    )
    with zipfile.ZipFile(BUNDLE, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in files:
            archive.write(path, path.relative_to(REPOSITORY).as_posix())
    with zipfile.ZipFile(BUNDLE) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"ZIP CRC failure: {bad}")
        expected_names = [path.relative_to(REPOSITORY).as_posix() for path in files]
        if sorted(archive.namelist()) != sorted(expected_names) or len(set(archive.namelist())) != len(expected_names):
            raise RuntimeError("ZIP entry parity failed")
        for path, name in zip(files, expected_names):
            if archive.read(name) != path.read_bytes():
                raise RuntimeError(f"ZIP byte parity failed: {name}")
    print(f"ZIP_PARITY=PASS entries={len(files)} integrity=PASS")
    for path in (PLACE, BUNDLE):
        data = path.read_bytes()
        print(f"ARTIFACT={path.name} bytes={len(data)} sha256={hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    PLACE.write_text(serialize(build_tree()), encoding="utf-8")
    audit_place()
    package()
