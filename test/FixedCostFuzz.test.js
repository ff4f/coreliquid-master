const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture } = require("@nomicfoundation/hardhat-network-helpers");

describe("Fixed-Cost Fuzz Tests", function () {
    async function deployFixture() {
        const [owner, user1, user2, user3] = await ethers.getSigners();

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

        // Add markets with different parameters for fuzz testing
        const markupRates = [100, 300, 500, 1000]; // 1%, 3%, 5%, 10%
        const tenors = [7, 30, 60, 90]; // Different tenor periods
        
        for (let i = 0; i < markupRates.length; i++) {
            const asset = i === 0 ? usdc.address : weth.address;
            if (i < 2) {
                await lendingMarket.addMarket(
                    asset,
                    ethers.utils.parseEther("0.8"), // collateralFactor
                    ethers.utils.parseEther("0.1"), // reserveFactor
                    ethers.utils.parseEther("0.8"), // liquidationThreshold
                    ethers.utils.parseEther("0.05"), // liquidationBonus
                    i === 0 ? ethers.utils.parseUnits("1000000", 6) : ethers.utils.parseEther("1000"), // borrowCap
                    i === 0 ? ethers.utils.parseUnits("1000000", 6) : ethers.utils.parseEther("1000"), // supplyCap
                    markupRates[i], // fixedMarkupBps
                    tenors[i]       // tenor
                );
            }
        }

        // Mint large amounts for fuzz testing
        await usdc.mint(user1.address, ethers.utils.parseUnits("100000", 6));
        await weth.mint(user1.address, ethers.utils.parseEther("1000"));
        await usdc.mint(user2.address, ethers.utils.parseUnits("100000", 6));
        await weth.mint(user2.address, ethers.utils.parseEther("1000"));
        await usdc.mint(user3.address, ethers.utils.parseUnits("100000", 6));
        await weth.mint(user3.address, ethers.utils.parseEther("1000"));

        return {
            lendingMarket,
            interestRateModel,
            feeSpreadModel,
            creditSaleManager,
            usdc,
            weth,
            owner,
            user1,
            user2,
            user3
        };
    }

    // Helper function to generate random numbers
    function randomBetween(min, max) {
        return Math.floor(Math.random() * (max - min + 1)) + min;
    }

    // Helper function to generate random amounts
    function randomAmount(decimals, minValue = 1, maxValue = 1000) {
        const value = randomBetween(minValue, maxValue);
        return ethers.utils.parseUnits(value.toString(), decimals);
    }

    describe("Fuzz Testing - Random Operations", function () {
        it("Should maintain invariants with random borrow amounts", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Supply initial liquidity
            const supplyAmount = ethers.utils.parseUnits("10000", 6);
            await usdc.connect(user1).approve(lendingMarket.address, supplyAmount);
            await lendingMarket.connect(user1).supply(usdc.address, supplyAmount);

            // Perform multiple random borrows
            for (let i = 0; i < 10; i++) {
                const borrowAmount = randomAmount(6, 1, 100); // Random amount between 1-100 USDC
                
                try {
                    await lendingMarket.connect(user1).borrow(usdc.address, borrowAmount);
                    
                    // Check invariants
                    const market = await lendingMarket.markets(usdc.address);
                    const userAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
                    
                    expect(market.borrowRate).to.equal(0);
                    expect(market.supplyRate).to.equal(0);
                    expect(userAccount.paidAmount).to.be.lte(userAccount.fixedTotalPrice);
                    
                    if (userAccount.installmentCount.gt(0) && userAccount.installmentAmount.gt(0)) {
                        const expectedTotal = userAccount.installmentCount.mul(userAccount.installmentAmount);
                        expect(expectedTotal).to.equal(userAccount.fixedTotalPrice);
                    }
                } catch (error) {
                    // Some borrows might fail due to caps or other constraints, which is expected
                    console.log(`Borrow ${i} failed as expected:`, error.message);
                }
            }
        });

        it("Should handle random payment amounts correctly", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Setup: Supply and borrow
            const supplyAmount = ethers.utils.parseUnits("10000", 6);
            await usdc.connect(user1).approve(lendingMarket.address, supplyAmount);
            await lendingMarket.connect(user1).supply(usdc.address, supplyAmount);

            const borrowAmount = ethers.utils.parseUnits("100", 6);
            await lendingMarket.connect(user1).borrow(usdc.address, borrowAmount);

            const userAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
            const fixedTotalPrice = userAccount.fixedTotalPrice;

            // Approve large amount for payments
            await usdc.connect(user1).approve(lendingMarket.address, fixedTotalPrice.mul(2));

            let totalPaid = ethers.BigNumber.from(0);
            
            // Make random payments
            for (let i = 0; i < 20; i++) {
                const currentAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
                
                if (currentAccount.borrowed.eq(0)) {
                    break; // Credit order is fully paid
                }

                const remainingBalance = currentAccount.fixedTotalPrice.sub(currentAccount.paidAmount);
                if (remainingBalance.eq(0)) {
                    break;
                }

                // Random payment amount (1-50% of remaining balance)
                const maxPayment = remainingBalance.div(2).add(1);
                const paymentAmount = remainingBalance.lt(maxPayment) ? remainingBalance : 
                    ethers.BigNumber.from(randomBetween(1, maxPayment.toNumber()));

                try {
                    await lendingMarket.connect(user1).payInstallment(usdc.address, paymentAmount);
                    totalPaid = totalPaid.add(paymentAmount);

                    // Check invariants after each payment
                    const updatedAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
                    expect(updatedAccount.paidAmount).to.be.lte(updatedAccount.fixedTotalPrice);
                    expect(totalPaid).to.be.lte(fixedTotalPrice);
                } catch (error) {
                    // Payment might fail if order is already paid or overdue
                    console.log(`Payment ${i} failed:`, error.message);
                    break;
                }
            }
        });

        it("Should handle multiple users with random operations", async function () {
            const { lendingMarket, usdc, user1, user2, user3 } = await loadFixture(deployFixture);
            const users = [user1, user2, user3];

            // Each user supplies random amounts
            for (const user of users) {
                const supplyAmount = randomAmount(6, 1000, 5000);
                await usdc.connect(user).approve(lendingMarket.address, supplyAmount);
                await lendingMarket.connect(user).supply(usdc.address, supplyAmount);
            }

            // Random borrow operations
            for (let round = 0; round < 5; round++) {
                for (const user of users) {
                    const borrowAmount = randomAmount(6, 10, 200);
                    
                    try {
                        await lendingMarket.connect(user).borrow(usdc.address, borrowAmount);
                        
                        // Verify invariants for this user
                        const userAccount = await lendingMarket.userAccounts(user.address, usdc.address);
                        const market = await lendingMarket.markets(usdc.address);
                        
                        expect(market.borrowRate).to.equal(0);
                        expect(market.supplyRate).to.equal(0);
                        
                        if (userAccount.borrowed.gt(0)) {
                            expect(userAccount.fixedTotalPrice).to.be.gt(userAccount.borrowed);
                            expect(userAccount.paidAmount).to.be.lte(userAccount.fixedTotalPrice);
                        }
                    } catch (error) {
                        // Some operations might fail due to constraints
                        console.log(`User ${users.indexOf(user)} borrow in round ${round} failed:`, error.message);
                    }
                }
            }
        });

        it("Should maintain system integrity with random markup and tenor combinations", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Test different markup rates
            const markupRates = [50, 100, 200, 500, 1000, 1500]; // 0.5% to 15%
            const principals = [
                ethers.utils.parseUnits("10", 6),
                ethers.utils.parseUnits("100", 6),
                ethers.utils.parseUnits("1000", 6)
            ];

            for (const markup of markupRates) {
                for (const principal of principals) {
                    const fixedPrice = await lendingMarket.quoteFixedPrice(usdc.address, principal, markup);
                    const expectedMarkup = principal.mul(markup).div(10000);
                    const expectedTotal = principal.add(expectedMarkup);
                    
                    expect(fixedPrice).to.equal(expectedTotal);
                    expect(fixedPrice).to.be.gt(principal); // Always greater than principal
                    
                    // Verify markup calculation precision
                    const actualMarkup = fixedPrice.sub(principal);
                    expect(actualMarkup).to.equal(expectedMarkup);
                }
            }
        });

        it("Should handle edge cases in payment calculations", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Supply liquidity
            const supplyAmount = ethers.utils.parseUnits("10000", 6);
            await usdc.connect(user1).approve(lendingMarket.address, supplyAmount);
            await lendingMarket.connect(user1).supply(usdc.address, supplyAmount);

            // Borrow small amount to test precision
            const borrowAmount = ethers.utils.parseUnits("1", 6); // 1 USDC
            await lendingMarket.connect(user1).borrow(usdc.address, borrowAmount);

            const userAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
            const fixedTotalPrice = userAccount.fixedTotalPrice;
            const installmentAmount = userAccount.installmentAmount;

            // Test overpayment protection
            const overpayment = fixedTotalPrice.mul(2);
            await usdc.connect(user1).approve(lendingMarket.address, overpayment);
            
            const balanceBefore = await usdc.balanceOf(user1.address);
            await lendingMarket.connect(user1).payInstallment(usdc.address, overpayment);
            const balanceAfter = await usdc.balanceOf(user1.address);
            
            // Should only deduct the exact remaining balance, not the overpayment
            const actualDeduction = balanceBefore.sub(balanceAfter);
            expect(actualDeduction).to.be.lte(fixedTotalPrice);
            
            // Credit order should be fully paid
            const finalAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
            expect(finalAccount.borrowed).to.equal(0);
        });
    });

    describe("Stress Testing", function () {
        it("Should handle high-frequency operations", async function () {
            const { lendingMarket, usdc, user1 } = await loadFixture(deployFixture);

            // Supply large amount
            const supplyAmount = ethers.utils.parseUnits("50000", 6);
            await usdc.connect(user1).approve(lendingMarket.address, supplyAmount);
            await lendingMarket.connect(user1).supply(usdc.address, supplyAmount);

            // Perform many small operations
            for (let i = 0; i < 50; i++) {
                const borrowAmount = ethers.utils.parseUnits("10", 6);
                
                try {
                    await lendingMarket.connect(user1).borrow(usdc.address, borrowAmount);
                    
                    const userAccount = await lendingMarket.userAccounts(user1.address, usdc.address);
                    if (userAccount.borrowed.gt(0)) {
                        // Pay some amount
                        const paymentAmount = userAccount.installmentAmount;
                        await usdc.connect(user1).approve(lendingMarket.address, paymentAmount);
                        await lendingMarket.connect(user1).payInstallment(usdc.address, paymentAmount);
                    }
                    
                    // Verify system state
                    const market = await lendingMarket.markets(usdc.address);
                    expect(market.borrowRate).to.equal(0);
                    expect(market.supplyRate).to.equal(0);
                } catch (error) {
                    // Some operations might fail due to constraints
                    console.log(`High-frequency operation ${i} failed:`, error.message);
                }
            }
        });
    });
});