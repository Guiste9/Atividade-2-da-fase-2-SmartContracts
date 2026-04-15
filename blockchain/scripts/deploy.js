const hre = require("hardhat");

async function main() {
  const Registro = await hre.ethers.getContractFactory("RegistroDeUsuariosComRecompensa");
  const registro = await Registro.deploy();
  await registro.waitForDeployment();

  const endereco = await registro.getAddress();
  console.log("Contrato implantado em:", endereco);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
