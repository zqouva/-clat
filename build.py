"""--> [`plugin packer`] -- packs Plugin/ + EclatData/ into Releases/*.rbxmx."""

import os
import xml.sax.saxutils as saxutils

print("--> [`eclat`]: packing...")

VERSION = "0.1.0"
SOURCE_DIR = "EclatData"
PLUGIN_DIR = "Plugin"
OUT_DIR = "Releases"
PLUGIN_NAME = f"EclatPlugin {VERSION}.rbxmx"


def escape(text):
    return saxutils.escape(text)


def referent():
    return "RBX" + os.urandom(8).hex()


def indent(text, depth=1):
    if not text:
        return ""
    prefix = "\t" * depth
    return "\n".join(f"{prefix}{line}" if line else line for line in text.splitlines())


def props(name, source=None):
    lines = [
        '<BinaryString name="AttributesSerialize"></BinaryString>',
        '<SecurityCapabilities name="Capabilities">0</SecurityCapabilities>',
        '<bool name="DefinesCapabilities">false</bool>',
        f'<string name="Name">{escape(name)}</string>',
    ]
    if source is not None:
        lines.append(f'<ProtectedString name="Source">{escape(source)}</ProtectedString>')
    lines.append('<int64 name="SourceAssetId">-1</int64>')
    lines.append('<BinaryString name="Tags"></BinaryString>')
    return "\n".join(lines)


def with_children(header, children_xml, footer="</Item>"):
    if children_xml:
        return f"{header}\n{indent(children_xml)}\n{footer}"
    return f"{header}\n{footer}"


def build_script_xml(name, source_content, class_name="ModuleScript"):
    header = (
        f'<Item class="{class_name}" referent="{referent()}">\n'
        "\t<Properties>\n"
        f"{indent(props(name, source_content), 2)}\n"
        "\t</Properties>"
    )
    return with_children(header, "")


def build_folder_xml(name, children_xml):
    header = (
        f'<Item class="Folder" referent="{referent()}">\n'
        "\t<Properties>\n"
        f"{indent(props(name), 2)}\n"
        "\t</Properties>"
    )
    return with_children(header, children_xml)


def build_module_xml(name, source_content, children_xml):
    header = (
        f'<Item class="ModuleScript" referent="{referent()}">\n'
        "\t<Properties>\n"
        f"{indent(props(name, source_content), 2)}\n"
        "\t</Properties>"
    )
    return with_children(header, children_xml)


def get_script_info(filename):
    """Returns (script_name, roblox_class) or None for non-script files."""
    if filename.endswith(".server.luau"):
        return filename[: -len(".server.luau")], "Script"
    if filename.endswith(".server.lua"):
        return filename[: -len(".server.lua")], "Script"
    if filename.endswith(".client.luau"):
        return filename[: -len(".client.luau")], "LocalScript"
    if filename.endswith(".client.lua"):
        return filename[: -len(".client.lua")], "LocalScript"
    if filename.endswith(".luau"):
        return filename[: -len(".luau")], "ModuleScript"
    if filename.endswith(".lua"):
        return filename[: -len(".lua")], "ModuleScript"
    return None


def read_source(path):
    with open(path, "r", encoding="utf-8", errors="ignore") as handle:
        return handle.read()


def scan_children(path, exclude=()):
    """XML for the children of a folder (init files are lifted by the caller)."""
    items_xml = []
    try:
        entries = sorted(os.listdir(path))
    except Exception:
        return ""

    for entry in entries:
        if entry.startswith(".") or entry in exclude:
            continue
        full_path = os.path.join(path, entry)
        if os.path.isdir(full_path):
            items_xml.append(scan_directory(full_path, exclude))
        else:
            if entry in ("init.luau", "init.lua"):
                continue
            info = get_script_info(entry)
            if info is None:
                continue
            name, class_name = info
            items_xml.append(build_script_xml(name, read_source(full_path), class_name))

    return "\n".join(item for item in items_xml if item)


def scan_directory(path, exclude=()):
    """A folder becomes a Folder — unless it holds init, then a ModuleScript."""
    name = os.path.basename(path.rstrip(os.sep))
    init_file = None
    for candidate in ("init.luau", "init.lua"):
        joined = os.path.join(path, candidate)
        if os.path.isfile(joined):
            init_file = joined
            break

    children_xml = scan_children(path, exclude)
    if init_file:
        print(f'--> [`eclat`]: packing module "{name}"...')
        return build_module_xml(name, read_source(init_file), children_xml)
    print(f'--> [`eclat`]: packing folder "{name}"...')
    return build_folder_xml(name, children_xml)


def wrap_model(root_xml):
    return (
        '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" '
        'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" '
        'xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">\n'
        '\t<Meta name="ExplicitAutoJoints">true</Meta>\n'
        "\t<External>null</External>\n"
        "\t<External>nil</External>\n"
        f"{indent(root_xml)}\n"
        "</roblox>\n"
    )


def write_model(out_name, root_xml):
    os.makedirs(OUT_DIR, exist_ok=True)
    model = wrap_model(root_xml)
    out_path = os.path.join(OUT_DIR, out_name)
    with open(out_path, "w", encoding="utf-8") as handle:
        handle.write(model)
    print(f'--> [`eclat`]: wrote {out_path} ({len(model)} bytes).')


def build_plugin():
    main_path = os.path.join(PLUGIN_DIR, "Main.server.luau")
    if not os.path.isfile(main_path):
        print(f'--> [`eclat`]: {main_path} not found. nothing to pack.')
        raise SystemExit(1)
    main_xml = build_script_xml("Main", read_source(main_path), "Script")
    data_xml = scan_directory(SOURCE_DIR, exclude=("Examples", "Validation"))
    data_xml = data_xml.replace(
        f'<string name="Name">{SOURCE_DIR}</string>',
        '<string name="Name">EclatData</string>',
        1,
    )
    root_xml = build_folder_xml("EclatPlugin", "\n".join([main_xml, data_xml]))
    write_model(PLUGIN_NAME, root_xml)


def main():
    if not os.path.isdir(SOURCE_DIR):
        print(f'--> [`eclat`]: {SOURCE_DIR}/ not found. nothing to pack.')
        raise SystemExit(1)
    build_plugin()


if __name__ == "__main__":
    main()
