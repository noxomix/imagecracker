# Kernel License Information

## vmlinux Binary

The `vmlinux` file included in this repository is a precompiled Linux kernel binary optimized for Firecracker virtual machines.

### License

The Linux kernel is licensed under the **GNU General Public License version 2 (GPLv2)**.

### Source Code

As required by the GPLv2 license, the complete source code for this kernel is available at:

- **Official Linux Kernel Repository**: https://git.kernel.org/
- **GitHub Mirror**: https://github.com/torvalds/linux

### Kernel Version

To check the exact kernel version of the included `vmlinux` binary, you can use:

```bash
file vmlinux
# or
strings vmlinux | grep "Linux version"
```

### GPLv2 License Text

The full text of the GNU General Public License version 2 can be found at:
- https://www.gnu.org/licenses/old-licenses/gpl-2.0.html
- https://www.kernel.org/doc/html/latest/process/license-rules.html

### Firecracker Compatibility

This kernel has been configured specifically for use with AWS Firecracker microVMs and includes:

- Minimal device drivers required for Firecracker
- Optimized for fast boot times
- Support for virtio devices
- No unnecessary modules to reduce size

### Building Your Own Kernel

If you prefer to build your own kernel, you can follow the Firecracker documentation:
- https://github.com/firecracker-microvm/firecracker/blob/main/docs/kernel-policy.md

### Compliance

This distribution complies with the GPLv2 license requirements by:

1. **Source Availability**: Providing clear references to where the complete source code can be obtained
2. **License Notice**: Including this license information file
3. **No Restrictions**: Not imposing any additional restrictions beyond those in the GPLv2

### Disclaimer

THE KERNEL IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE KERNEL OR THE USE OR OTHER DEALINGS IN THE KERNEL.