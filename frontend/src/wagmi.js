import { createConfig, http } from "wagmi";
import { injected } from "wagmi/connectors";
import { hardhat, sepolia } from "wagmi/chains";

export const wagmiConfig = createConfig({
  chains: [hardhat, sepolia],
  connectors: [injected()],
  transports: {
    [hardhat.id]: http("http://127.0.0.1:8545"),
    [sepolia.id]: http(),
  },
});
