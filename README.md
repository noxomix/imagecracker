# ImageCracker - Universal Firecracker Image Builder

Ein universelles CLI-Tool zum Erstellen von Firecracker VM-Images aus beliebigen Verzeichnissen mit Dockerfiles.

## Features

- 🔧 **Universell**: Funktioniert in jedem Verzeichnis mit einer Dockerfile
- 📦 **Automatische Optimierung**: Verkleinert Images standardmäßig auf tatsächlich benötigte Größe
- 🎯 **Flexibel**: Anpassbare Parameter für verschiedene Use Cases
- 🔗 **Global verfügbar**: Symlink-Installation für systemweiten Zugriff
- 🏠 **Benutzer-spezifisch**: Images werden im User-Home-Verzeichnis gespeichert

## Installation

### Symlink für globalen Zugriff installieren
```bash
cd ~/imagecracker
./imagecracker.sh setup
```

Nach der Installation können Sie `imagecracker` von überall verwenden!

## Verwendung

### Basis-Syntax
```bash
imagecracker <COMMAND> [OPTIONS] [DIRECTORY]
```

### Verfügbare Commands
- `build` - Erstellt ein Firecracker Image aus einer Dockerfile
- `setup` - Installiert Symlink für globalen Zugriff

### Build-Optionen
- `-n, --name NAME` - Image-Name (erforderlich)
- `-d, --directory DIR` - Ausgabe-Verzeichnis (Standard: `$HOME/firecracker_images`)
- `-k, --kernel KERNEL` - Pfad zu vmlinux Kernel (Standard: mitgelieferter Kernel)
- `--no-compact` - Optimierung deaktivieren (volle Größe beibehalten)
- `-s, --size SIZE` - Initiale RootFS-Größe in MB (Standard: 2048)
- `-h, --help` - Hilfe anzeigen

### Beispiele

#### Einfacher Build im aktuellen Verzeichnis
```bash
imagecracker build --name myapp .
```

#### Produktions-Image (automatisch optimiert)
```bash
imagecracker build --name production /path/to/project
```

#### Image ohne Optimierung (volle Größe)
```bash
imagecracker build --name fullsize --no-compact /path/to/project
```

#### Mit eigenem Kernel und größerem Image
```bash
imagecracker build --name bigapp --kernel /path/to/vmlinux --size 4096 .
```

#### In eigenes Verzeichnis speichern
```bash
imagecracker build --name testapp --directory /tmp/my-images .
```

#### Setup für globalen Zugriff
```bash
imagecracker setup
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
2. **Build**: Führen Sie `imagecracker build --name <name> .` aus
3. **Verwendung**: Die fertigen Images befinden sich in `$HOME/firecracker_images/<name>/`

## Mitgelieferte Dateien

- `imagecracker.sh` - Das Hauptskript
- `vmlinux` - Standard Linux-Kernel für Firecracker VMs
- `README.md` - Diese Dokumentation

## Tipps

- Verwenden Sie sprechende Namen für Ihre Images (`-n dev`, `-n prod`, etc.)
- Images werden standardmäßig optimiert (auf tatsächliche Größe verkleinert)
- Verwenden Sie `--no-compact` nur wenn Sie die volle Größe benötigen
- Der mitgelieferte Kernel funktioniert mit den meisten Anwendungen
- Images werden automatisch überschrieben wenn Sie den gleichen Namen verwenden