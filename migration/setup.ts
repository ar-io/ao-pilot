import fs from "fs";
import path from "path";
import { ArIO, ArweaveSigner, IO } from "@ar.io/sdk";
import Arweave from 'arweave'

export const migratedProcessId = "GaQrvEMKBpkjofgnBi_B3IgIDmY_XYelVLB6GcRGrHc";
export const smartWeaveTxId = "_NctcA2sRy1-J4OmIQZbYFPM17piNcbdBPH2ncX2RL8"; // "bLAgYxAdX2Ry-nt6aH2ixgvJXbpsEYm28NgJgyqfs-U";
export const dirname = new URL(import.meta.url).pathname;
export const jwk = JSON.parse(
  fs.readFileSync(path.join(dirname, "../wallet.json")).toString(),
);
export const signer = new ArweaveSigner(jwk);
export const devnetContract = ArIO.init({
  contractTxId: smartWeaveTxId,
});
export const ioContract = IO.init({
  processId: migratedProcessId,
  signer,
});
export   const arweave = Arweave.init({
    host: "arweave.net",
    port: 443,
    protocol: "https",
  });
// give team members additional tokens
export const teamMembers = new Set([
    "6Z-ifqgVi1jOwMvSNwKWs6ewUEQ0gU9eo4aHYC3rN1M", // anthony
    "nszYSUJvtlFXssccPaQWZaVpkXgJHcVM7XhcP5NEt7w", // jonathon,
    "GtDQcrr2QRdoZ-lKto_S_SpzEwiZiHVaj3x4jAgRh4o", // stephen
    "ZjmB2vEUlHlJ7-rgJkYP09N5IzLPhJyStVrK5u9dDEo", // dylan.ar
    "1H7WZIWhzwTH9FIcnuMqYkTsoyv1OTfGa_amvuYwrgo", // permagate.ar
    "NdZ3YRwMB2AMwwFYjKn1g88Y9nRybTo0qhS1ORq_E7g", // phil
    "7waR8v4STuwPnTck1zFVkQqJh5K9q9Zik4Y5-5dV7nk", // atticus
    "N4h8M9A9hasa3tF47qQyNvcKjm4APBKuFs7vqUVm-SI", // steven
    "9jfM0uzGNc9Mkhjo1ixGoqM7ygSem9wx_EokiVgi0Bs", // gisela
    "hNtcagQ0tlXOLM8uhwI408efFSI5DiqHGoP_BqUfzOQ", // david
    // TODO: add anyone else
]);

export const teamGateways = new Set([
    "1H7WZIWhzwTH9FIcnuMqYkTsoyv1OTfGa_amvuYwrgo", // permagate.ar
    "wlcEhTQY_qjDKTvTDZsb53aX8wivbOJZKnhLswdueZw", // vilenarios.com
    "QGWqtJdLLgm2ehFWiiPzMaoFLD50CnGuzZIPEdoDRGQ", // ar-io.dev
]);
export const excludeWallets = new Set([smartWeaveTxId, teamMembers]); // TODO: add team wallets
