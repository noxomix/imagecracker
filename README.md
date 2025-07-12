# ImageCracker - Universal Firecracker Image Builder

Ein universelles CLI-Tool zum Erstellen von Firecracker VM-Images aus beliebigen Verzeichnissen mit Dockerfiles.

## Features

- 🔧 **Universell**: Funktioniert in jedem Verzeichnis mit einer Dockerfile
- 📦 **Automatische Optimierung**: Komprimiert Images auf minimale Größe
- 🎯 **Flexibel**: Anpassbare Parameter für verschiedene Use Cases
- 🔗 **Global verfügbar**: Symlink-Installation für systemweiten Zugriff
- 🏠 **Benutzer-spezifisch**: Images werden im User-Home-Verzeichnis gespeichert

## Installation

### Symlink für globalen Zugriff installieren
```bash
cd ~/imagecracker
./imagecracker.sh -symlink
```

Nach der Installation können Sie `imagecracker` von überall verwenden!

## Verwendung

### Basis-Syntax
```bash
imagecracker [OPTIONS] [DIRECTORY]
```

### Verfügbare Optionen
- `-n NAME` - Image-Name (erforderlich)
- `-d DIRECTORY` - Ausgabe-Verzeichnis (Standard: `$HOME/firecracker_images`)
- `-k KERNEL` - Pfad zu vmlinux Kernel (Standard: mitgelieferter Kernel)
- `-c` - RootFS komprimieren
- `-s SIZE` - Initiale RootFS-Größe in MB (Standard: 2048)
- `-symlink` - Symlink für globalen Zugriff installieren
- `-h, --help` - Hilfe anzeigen

### Beispiele

#### Einfacher Build im aktuellen Verzeichnis
```bash
imagecracker -n myapp .
```

#### Komprimiertes Produktions-Image
```bash
imagecracker -n production -c /path/to/project
```

#### Mit eigenem Kernel und größerem Image
```bash
imagecracker -n bigapp -k /path/to/vmlinux -s 4096 .
```

#### In eigenes Verzeichnis speichern
```bash
imagecracker -n testapp -d /tmp/my-images .
```

## Anforderungen

- Dockerfile im Zielverzeichnis
- Docker installiert und laufend
- Root/sudo-Zugriff für Image-Operationen
- Standard Linux-Tools: `dd`, `mkfs.ext4`, `e2fsck`, `resize2fs`, etc.

## Ausgabe-Struktur

Images werden strukturiert gespeichert:

```
$HOME/firecracker_images/
├── myapp/
│   ├── vmlinux        # Kernel für diese VM
│   └── rootfs.ext4    # Root-Dateisystem
├── production/
│   ├── vmlinux
│   └── rootfs.ext4
└── ...
```

## Workflow

1. **Vorbereitung**: Wechseln Sie in ein Verzeichnis mit einer Dockerfile
2. **Build**: Führen Sie `imagecracker -n <name> .` aus
3. **Verwendung**: Die fertigen Images befinden sich in `$HOME/firecracker_images/<name>/`

## Mitgelieferte Dateien

- `imagecracker.sh` - Das Hauptskript
- `vmlinux` - Standard Linux-Kernel für Firecracker VMs
- `README.md` - Diese Dokumentation

## Tipps

- Verwenden Sie sprechende Namen für Ihre Images (`-n dev`, `-n prod`, etc.)
- Nutzen Sie Kompression (`-c`) für kleinere Image-Dateien
- Der mitgelieferte Kernel funktioniert mit den meisten Anwendungen
- Images werden automatisch überschrieben wenn Sie den gleichen Namen verwenden