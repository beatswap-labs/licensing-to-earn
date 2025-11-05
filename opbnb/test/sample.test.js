const { expect } = require("chai");

describe("IPLicensingIndex", function () {
  it("deploys", async function () {
    const [owner] = await ethers.getSigners();
    const F = await ethers.getContractFactory("IPLicensingIndex");
    const c = await F.deploy(owner.address);
    await c.waitForDeployment();
    expect(await c.name()).to.equal("IPLicensingIndex");
    expect(await c.symbol()).to.equal("IPL");
  });
});
