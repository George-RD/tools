// Preload shim for hosts where os.networkInterfaces() throws.
//
// This VM's kernel/netlink layer rejects uv_interface_addresses (error 97), which
// breaks tooling that enumerates interfaces (e.g. Remotion's port-config). The shim
// only replaces the function when the real call fails, so on healthy hosts it is
// a no-op. Use via NODE_OPTIONS="--require /path/to/this-file.cjs".
const os = require('node:os');

try {
  os.networkInterfaces();
} catch (err) {
  const loopback = {
    lo: [
      {
        address: '127.0.0.1',
        netmask: '255.0.0.0',
        family: 'IPv4',
        mac: '00:00:00:00:00:00',
        internal: true,
        cidr: '127.0.0.1/8',
      },
      {
        address: '::1',
        netmask: 'ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff',
        family: 'IPv6',
        mac: '00:00:00:00:00:00',
        scopeid: 0,
        internal: true,
        cidr: '::1/128',
      },
    ],
  };
  os.networkInterfaces = () => loopback;
}
