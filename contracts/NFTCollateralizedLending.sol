// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFTCollateralizedLending is Ownable {
    // Structure to store collateral details
    struct Collateral {
        address nftContract;
        uint256 tokenId;
        uint256 loanAmount;
        address borrower;
        bool active;
    }

    // ERC20 token used for lending and borrowing
    IERC20 public lendingToken;

    // Mapping from NFT (contract + tokenId) to collateral
    mapping(address => mapping(uint256 => Collateral)) public collaterals;

    event CollateralDeposited(
        address indexed borrower,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 loanAmount
    );
    event LoanRepaid(
        address indexed borrower,
        address indexed nftContract,
        uint256 indexed tokenId
    );

    constructor(
        address _lendingToken,
        address initialOwner
    ) Ownable(initialOwner) {
        lendingToken = IERC20(_lendingToken);
    }

    // Function to deposit an NFT as collateral and borrow tokens
    function depositCollateral(
        address nftContract,
        uint256 tokenId,
        uint256 loanAmount
    ) external {
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "You are not the owner of this NFT"
        );
        require(
            collaterals[nftContract][tokenId].active == false,
            "NFT is already collateralized"
        );

        // Transfer NFT to the contract
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        // Transfer loan amount to borrower
        require(
            lendingToken.transfer(msg.sender, loanAmount),
            "Failed to transfer loan amount"
        );

        // Create collateral record
        collaterals[nftContract][tokenId] = Collateral({
            nftContract: nftContract,
            tokenId: tokenId,
            loanAmount: loanAmount,
            borrower: msg.sender,
            active: true
        });

        emit CollateralDeposited(msg.sender, nftContract, tokenId, loanAmount);
    }

    // Function to repay the loan and retrieve the collateral
    function repayLoan(address nftContract, uint256 tokenId) external {
        Collateral storage collateral = collaterals[nftContract][tokenId];
        require(collateral.active, "Collateral not active");
        require(collateral.borrower == msg.sender, "You are not the borrower");

        // Transfer loan amount back to the contract
        require(
            lendingToken.transferFrom(
                msg.sender,
                address(this),
                collateral.loanAmount // TODO: + calculateLoanInterest(collateral)
            ),
            "Failed to repay loan"
        );

        // Transfer NFT back to the borrower
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);

        // Mark collateral as inactive
        collateral.active = false;

        emit LoanRepaid(msg.sender, nftContract, tokenId);
    }

    // Function to withdraw lending token profits (only owner)
    function withdrawProfits(uint256 amount) external onlyOwner {
        require(
            lendingToken.transfer(msg.sender, amount),
            "Failed to transfer profits"
        );
    }
}
