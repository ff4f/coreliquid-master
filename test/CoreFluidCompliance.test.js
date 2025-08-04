const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("CoreFluid Compliance Tests", function () {
    let lendingMarket;
    let interestRateModel;
    let feeSpreadModel;
    let creditSaleManager;
    let owner, user1, user2;
    let mockToken;

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // Deploy mock token
        const MockToken = await ethers.getContractFactory("MockERC20");
        mockToken = await MockToken.deploy("Test Token", "TEST", 18);
        await mockToken.deployed();

        // Deploy InterestRateModel
        const InterestRateModel = await ethers.getContractFactory("InterestRateModel");
        interestRateModel = await InterestRateModel.deploy();
        await interestRateModel.deployed();

        // Deploy FeeSpreadModel
        const FeeSpreadModel = await ethers.getContractFactory("FeeSpreadModel");
        feeSpreadModel = await FeeSpreadModel.deploy();
        await feeSpreadModel.deployed();

        // Deploy CreditSaleManager
        const CreditSaleManager = await ethers.getContractFactory("CreditSaleManager");
        creditSaleManager = await CreditSaleManager.deploy();
        await creditSaleManager.deployed();

        // Deploy LendingMarket
        const LendingMarket = await ethers.getContractFactory("LendingMarket");
        lendingMarket = await LendingMarket.deploy(
            interestRateModel.address,
            owner.address, // priceOracle
            owner.address, // treasury
            feeSpreadModel.address,
            creditSaleManager.address
        );
        await lendingMarket.deployed();
    });

    describe("Interest Rate Compliance", function () {
        it("Should return 0 interest rate when CoreFluid mode enabled", async function () {
            // Enable zero-interest mode
            await interestRateModel.setCoreFluidMode(true);
            
            // Test calculateInterestRate returns 0
            const interestRate = await interestRateModel.calculateInterestRate(5000); // 50% utilization
            expect(interestRate).to.equal(0);
        });

        it("Should have interestRate = 0 invariant in CoreFluid mode", async function () {
            // Enable zero-interest mode
            await lendingMarket.setCoreFluidMode(true);
            
            // Test supply APY is 0
            const supplyAPY = await lendingMarket.calculateSupplyAPY(mockToken.address);
            expect(supplyAPY).to.equal(0);
        });

        it("Should disable interest when interestDisabled flag is set", async function () {
            await lendingMarket.setInterestDisabled(true);
            
            const supplyAPY = await lendingMarket.calculateSupplyAPY(mockToken.address);
            expect(supplyAPY).to.equal(0);
        });
    });

    describe("Credit Sale System", function () {
        it("Should allow requesting credit sale quotes", async function () {
            // Setup fee spread for asset
            await feeSpreadModel.setAssetFeeSpread(mockToken.address, 500); // 5%
            
            // Request quote
            const assetAmount = ethers.utils.parseEther("100");
            const installments = 12;
            
            await expect(
                lendingMarket.requestCreditSale(
                    mockToken.address,
                    assetAmount,
                    installments,
                    user1.address
                )
            ).to.not.be.reverted;
        });

        it("Should get fee spread quote correctly", async function () {
            await feeSpreadModel.setAssetFeeSpread(mockToken.address, 800); // 8%
            
            const assetAmount = ethers.utils.parseEther("1000");
            const quote = await lendingMarket.getFeeSpreadQuote(
                mockToken.address,
                assetAmount,
                12
            );
            
            expect(quote.feeSpread).to.equal(800);
            expect(quote.fixedPrice).to.be.gt(assetAmount); // Should be higher due to markup
        });
    });

    describe("CoreFluid Mode Restrictions", function () {
        beforeEach(async function () {
            await lendingMarket.setCoreFluidMode(true);
        });

        it("Should revert traditional borrow in CoreFluid mode", async function () {
            await expect(
                lendingMarket.borrow(mockToken.address, ethers.utils.parseEther("100"))
            ).to.be.revertedWith("Traditional borrowing disabled in CoreFluid mode");
        });

        it("Should allow supply operations in CoreFluid mode", async function () {
            // Mint tokens to user
            await mockToken.mint(user1.address, ethers.utils.parseEther("1000"));
            await mockToken.connect(user1).approve(lendingMarket.address, ethers.utils.parseEther("100"));
            
            // Should not revert
            await expect(
                lendingMarket.connect(user1).supply(mockToken.address, ethers.utils.parseEther("100"))
            ).to.not.be.reverted;
        });
    });

    describe("Fee Spread Model", function () {
        it("Should calculate fixed price with markup", async function () {
            const assetAmount = ethers.utils.parseEther("1000");
            const feeSpread = 600; // 6%
            
            await feeSpreadModel.setAssetFeeSpread(mockToken.address, feeSpread);
            
            const fixedPrice = await feeSpreadModel.calculateFixedPrice(
                mockToken.address,
                assetAmount,
                12
            );
            
            // Fixed price should be asset amount + 6% markup
            const expectedPrice = assetAmount.mul(10600).div(10000);
            expect(fixedPrice).to.equal(expectedPrice);
        });

        it("Should apply risk factors correctly", async function () {
            await feeSpreadModel.setAssetRiskFactor(mockToken.address, 150); // 1.5x risk multiplier
            await feeSpreadModel.setAssetFeeSpread(mockToken.address, 500); // 5% base
            
            const assetAmount = ethers.utils.parseEther("1000");
            const fixedPrice = await feeSpreadModel.calculateFixedPrice(
                mockToken.address,
                assetAmount,
                12
            );
            
            // Should apply risk factor: 5% * 1.5 = 7.5% total markup
            const expectedPrice = assetAmount.mul(10750).div(10000);
            expect(fixedPrice).to.equal(expectedPrice);
        });
    });

    describe("Invariant Tests", function () {
        it("Should maintain interestRate = 0 invariant", async function () {
            await lendingMarket.setCoreFluidMode(true);
            
            // Test multiple scenarios
            const scenarios = [
                { utilization: 0 },
                { utilization: 2500 }, // 25%
                { utilization: 5000 }, // 50%
                { utilization: 7500 }, // 75%
                { utilization: 9000 }  // 90%
            ];
            
            for (const scenario of scenarios) {
                const rate = await interestRateModel.calculateInterestRate(scenario.utilization);
                expect(rate).to.equal(0, `Interest rate should be 0 for utilization ${scenario.utilization}`);
            }
        });

        it("Should ensure totalPaid <= totalPrice in credit sales", async function () {
            // This would be implemented with actual credit sale logic
            // For now, we just verify the quote calculation
            await feeSpreadModel.setAssetFeeSpread(mockToken.address, 1000); // 10%
            
            const assetAmount = ethers.utils.parseEther("1000");
            const quote = await lendingMarket.getFeeSpreadQuote(
                mockToken.address,
                assetAmount,
                12
            );
            
            // Total price should be asset amount + markup
            expect(quote.fixedPrice).to.be.gte(assetAmount);
            expect(quote.fixedPrice).to.be.lte(assetAmount.mul(120).div(100)); // Max 20% markup
        });
    });
});