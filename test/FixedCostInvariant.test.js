const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Fixed-Cost Invariant Tests", function () {
    async function deployFixture() {
        const [owner, user1, user2] = await ethers.getSigners();

        // Deploy mock ERC20 token
        const MockERC20 = await ethers.getContractFactory("MockERC20");
        const usdc = await MockERC20.deploy("USD Coin", "USDC", 6);
        const weth = await MockERC20.deploy("Wrapped Ether", "WETH", 18);

        // Deploy InterestRateModel
        const InterestRateModel = await ethers.getContractFactory("InterestRateModel");
        const interestRateModel = await InterestRateModel.deploy();

        // Deploy FeeSpreadModel
        const FeeSpreadModel = await ethers.getContractFactory("FeeSpreadModel");
        const feeSpreadModel = await FeeSpreadModel.deploy();

        // Deploy CreditSaleManager
        const CreditSaleManager = await ethers.getContractFactory("CreditSaleManager");
        const creditSaleManager = await CreditSaleManager.deploy();

        // Deploy LendingMarket
        const LendingMarket = await ethers.getContractFactory("LendingMarket");
        const lendingMarket = await LendingMarket.deploy(
            interestRateModel.address,
            feeSpreadModel.address,
            creditSaleManager.address,
            ethers.constants.AddressZero, // Oracle placeholder
            owner.address // Treasury
        );

        // Add markets with fixed-cost compliant parameters
        await lendingMarket.addMarket(
            usdc.address,
            ethers.utils.parseEther("0.8"), // collateralFactor
            ethers.utils.parseEther("0.1"), // reserveFactor
            ethers.utils.parseEther("0.8"), // liquidationThreshold
            ethers.utils.parseEther("0.05"), // liquidationBonus
            ethers.utils.parseUnits("1000000", 6), // borrowCap
            ethers.utils.parseUnits("1000000", 6), // supplyCap
            500, // fixedMarkupBps (5%)
            30   // tenor (30 days)
        );

        await lendingMarket.addMarket(
            weth.address,
            ethers.utils.parseEther("0.75"), // collateralFactor
            ethers.utils.parseEther("0.1"), // reserveFactor
            ethers.utils.parseEther("0.8"), // liquidationThreshold
            ethers.utils.parseEther("0.05"), // liquidationBonus
            ethers.utils.parseEther("1000"), // borrowCap
            ethers.utils.parseEther("1000"), // supplyCap
            300, // fixedMarkupBps (3%)
            60   // tenor (60 days)
        );

        // Mint tokens for testing
        await usdc.mint(user1.address, ethers.utils.parseUnits("10000", 6));
        await weth.mint(user1.address, ethers.utils.parseEther("100"));
        await usdc.mint(user2.address, ethers.utils.parseUnits("10000", 6));
        await weth.mint(user2.address, ethers.utils.parseEther("100"));

        return {
            lendingMarket,
            interestRateModel,
            feeSpreadModel,
            creditSaleManager,
            usdc,
            weth,
            owner,
            user1,
            user2
        };
    }

    describe("Core Invariants", function () {
        it("Should always have borrowRate and supplyRate equal to 0", async function () {
            const { lendingMarket, usdc, weth } = await loadFixture(deployFixture);

            const usdcMarket = await lendingMarket.markets(usdc.address);
            const wethMarket = await lendingMarket.markets(weth.address);

            expect(usdcMarket.borrowRate).to.equal(0);
            expect(usdcMarket.supplyRate).to.equal(0);
            expect(wethMarket.borrowRate).to.equal(0);
            expect(wethMarket.supplyRate).to.equal(0);
        });

        it("Should maintain borrowRate and supplyRate as 0 after operations", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Supply operation
            await usdc.connect(user1).approve(lendingMarket.address, ethers.utils.parseUnits("1000", 6));
            await lendingMarket.connect(user1).supply(usdc.address, ethers.utils.parseUnits("1000", 6));

            // Borrow operation
            await lendingMarket.connect(user1).borrow(usdc.address, ethers.utils.parseUnits("100", 6));

            const market = await lendingMarket.markets(usdc.address);
            expect(market.borrowRate).to.equal(0);
            expect(market.supplyRate).to.equal(0);
        });

        it("Should ensure totalPaid never exceeds fixedTotalPrice", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Supply first
            await usdc.connect(user1).approve(lendingMarket.address, ethers.utils.parseUnits("1000", 6));
            await lendingMarket.connect(user1).supply(usdc.address, ethers.utils.parseUnits("1000", 6));

            // Borrow
            const borrowAmount = ethers.utils.parseUnits("100", 6);
            await lendingMarket.connect(user1).borrow(usdc.address, borrowAmount);

            const userAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
            const fixedTotalPrice = userAccount.fixedTotalPrice;

            // Pay installments
            const installmentAmount = userAccount.installmentAmount;
            await usdc.connect(user1).approve(lendingMarket.address, fixedTotalPrice);
            
            // Pay multiple installments
            for (let i = 0; i < 5; i++) {
                const accountBefore = await lendingMarket.userAccounts(user1.address, usdc.address);
                if (accountBefore.paidAmount.lt(accountBefore.fixedTotalPrice)) {
                    await lendingMarket.connect(user1).payInstallment(usdc.address, installmentAmount);
                    
                    const accountAfter = await lendingMarket.userAccounts(user1.address, usdc.address);
                    expect(accountAfter.paidAmount).to.be.lte(accountAfter.fixedTotalPrice);
                }
            }
        });

        it("Should ensure installmentCount * installmentAmount equals fixedTotalPrice", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Supply first
            await usdc.connect(user1).approve(lendingMarket.address, ethers.utils.parseUnits("1000", 6));
            await lendingMarket.connect(user1).supply(usdc.address, ethers.utils.parseUnits("1000", 6));

            // Borrow
            const borrowAmount = ethers.utils.parseUnits("100", 6);
            await lendingMarket.connect(user1).borrow(usdc.address, borrowAmount);

            const userAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
            const expectedTotal = userAccount.installmentCount.mul(userAccount.installmentAmount);
            
            expect(expectedTotal).to.equal(userAccount.fixedTotalPrice);
        });
    });

    describe("Fixed Price Calculation Tests", function () {
        it("Should calculate correct fixed price with markup", async function () {
            const { lendingMarket, usdc } = await loadFixture(deployFixture);

            const principal = ethers.utils.parseUnits("100", 6);
            const markupBps = 500; // 5%
            
            const fixedPrice = await lendingMarket.quoteFixedPrice(usdc.address, principal, markupBps);
            const expectedPrice = principal.add(principal.mul(markupBps).div(10000));
            
            expect(fixedPrice).to.equal(expectedPrice);
        });

        it("Should handle different markup rates correctly", async function () {
            const { lendingMarket, usdc } = await loadFixture(deployFixture);

            const principal = ethers.utils.parseUnits("1000", 6);
            const markupRates = [100, 300, 500, 1000]; // 1%, 3%, 5%, 10%
            
            for (const markup of markupRates) {
                const fixedPrice = await lendingMarket.quoteFixedPrice(usdc.address, principal, markup);
                const expectedPrice = principal.add(principal.mul(markup).div(10000));
                expect(fixedPrice).to.equal(expectedPrice);
            }
        });
    });

    describe("Credit Order Lifecycle Tests", function () {
        it("Should properly initialize credit order on borrow", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Supply first
            await usdc.connect(user1).approve(lendingMarket.address, ethers.utils.parseUnits("1000", 6));
            await lendingMarket.connect(user1).supply(usdc.address, ethers.utils.parseUnits("1000", 6));

            // Borrow
            const borrowAmount = ethers.utils.parseUnits("100", 6);
            await lendingMarket.connect(user1).borrow(usdc.address, borrowAmount);

            const userAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
            const market = await lendingMarket.markets(usdc.address);
            
            expect(userAccount.borrowed).to.equal(borrowAmount);
            expect(userAccount.paidAmount).to.equal(0);
            expect(userAccount.paidInstallments).to.equal(0);
            expect(userAccount.installmentCount).to.equal(market.tenor);
            expect(userAccount.dueDate).to.be.gt(0);
        });

        it("Should clear credit order when fully paid", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Supply first
            await usdc.connect(user1).approve(lendingMarket.address, ethers.utils.parseUnits("1000", 6));
            await lendingMarket.connect(user1).supply(usdc.address, ethers.utils.parseUnits("1000", 6));

            // Borrow
            const borrowAmount = ethers.utils.parseUnits("100", 6);
            await lendingMarket.connect(user1).borrow(usdc.address, borrowAmount);

            const userAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
            const fixedTotalPrice = userAccount.fixedTotalPrice;

            // Pay full amount
            await usdc.connect(user1).approve(lendingMarket.address, fixedTotalPrice);
            await lendingMarket.connect(user1).payInstallment(usdc.address, fixedTotalPrice);

            const finalAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
            expect(finalAccount.borrowed).to.equal(0);
            expect(finalAccount.fixedTotalPrice).to.equal(0);
            expect(finalAccount.paidAmount).to.equal(0);
            expect(finalAccount.dueDate).to.equal(0);
        });
    });
});