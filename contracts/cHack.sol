// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

     /**
     * @notice The Loop Compound NFT
     * Documentation :
     * 
     * @author Ian Decentralize <idecentralize.eth>
     * 
     */

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/presets/ERC721PresetMinterPauserAutoIdUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

// Compound Interface
import "./interfaces/compound/Comptroller.sol";
import "./interfaces/compound/CErc20.sol";
import "./interfaces/compound/CEther.sol";
import "./interfaces/compound/Oracle.sol";

contract cHack is Initializable, OwnableUpgradeable, ERC721PresetMinterPauserAutoIdUpgradeable {

  using SafeMathUpgradeable for uint;

  bytes32 LOOP_ADMIN_ROLE;     
  address LOOP;
  address cEther;
    uint256 maxCompNftSupply;                     // maxNftSupply
    uint256 initCompNftPrice;                     // initial nft price
    uint256 CompInitialEth;                       // Locked Into Compound.
    address ETHER;
    uint256 loanFee;
    Comptroller comptroller;
    Oracle priceOracle;                           // REFERENCE ONLY


    // Loan Info
    bool public loan;                             // set to true on borrow
    uint256 loanedAmount;                         // loan info
    address loanedAsset;                          // borowed asset
    uint256 balanceBeforeLoan;                    // balance before loan
    
    mapping(address => bool) public loopCompNftOwners;               // NFT Registery (unique per account)
    mapping(address => bool) public loopCompMarket;           // Entered market on Compound
    mapping(address => address) public loopCToken;            // Return the cToken address of the asset
    mapping(address => uint256) public loopLoanCumulatedFees; // for nft owners              
   
    event NftSold(address user); 

    function LoopInitialize(
      string memory name,
      string memory symbol,
      uint256 fees,
      string memory uri,
      address loopAdmin
    ) public virtual initializer {
        __ERC721PresetMinterPauserAutoId_init(name, symbol, uri);
        _setupRole(LOOP_ADMIN_ROLE, loopAdmin);
        _setupRole(MINTER_ROLE, loopAdmin);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        address comptrollerAddress = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
        address UniswapAnchoredView = 0x922018674c12a7F0D394ebEEf9B58F186CdE13c1;
        cEther = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
        comptroller = Comptroller(comptrollerAddress);
        priceOracle = Oracle(UniswapAnchoredView);
        initCompNftPrice = 1000000000000000000;
        loanFee = fees;
    }

   ///////////////////////////////////////////////////////
   //              COMPOUND LOAN
   //

    // NOTE: The fees should be calculated here is the NFT give or not a bonus

    /// @notice BORROW Interfacable
    /// @param amount the amount we to take the fees on
    /// @param asset the account that is paying the fees
    
     

    function _borrow(uint256 amount, address asset) public whenNotPaused returns(uint256){ 
        require(hasRole(LOOP_ADMIN_ROLE, msg.sender), "Unauthorized");
        require(!loan,'Whut!');
        loan = true;
        loanedAmount = amount;
        loanedAsset = asset;
        require(loopCompMarket[asset],'Unsuported Asset!');
        ERC20Upgradeable token = ERC20Upgradeable(asset);
        balanceBeforeLoan = token.balanceOf(address(this));
        CErc20 cToken = CErc20(loopCToken[asset]);
        require(cToken.borrow(amount) == 0, "got collateral?");
        token.transfer(LOOP, amount); 
        // we have funds in the LOOP

        return 0;
    }

    /// @notice Repay Loop Compound Loan

    function _repay() public whenNotPaused returns(uint256){
         require(hasRole(LOOP_ADMIN_ROLE, msg.sender), "Unauthorized");
         CErc20 cToken = CErc20(loopCToken[loanedAsset]);
         ERC20Upgradeable asset = ERC20Upgradeable(loanedAsset);
         asset.transferFrom(LOOP, address(this), loanedAmount);
         require(  asset.balanceOf(address(this)) >=  balanceBeforeLoan.add(  loanedAmount.add(getLoanFees(loanedAmount,msg.sender))   ),'Reapy Short!');
         asset.approve(loanedAsset, loanedAmount);
         loopLoanCumulatedFees[loanedAsset] = loopLoanCumulatedFees[loanedAsset].add(getLoanFees(loanedAmount,msg.sender));
         require(cToken.repayBorrow(loanedAmount) == 0);
         require(asset.balanceOf(address(this)) >= balanceBeforeLoan.add(getLoanFees(loanedAmount,msg.sender)));
         // resetting loan to 0
         loan = false;
         loanedAsset = ETHER; // 0x000... // ETH can't be borrowed
         loanedAmount = 0;
         
        return 0;
    }

    /// @notice ENTER COMPOUND MARKET.
    /// @param _asset The asset to enter with;
    function _enterCompMarket(address _asset, address _ctoken) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Unauthorized");
        loopCToken[_asset] = _ctoken;
        loopCompMarket[_asset] = true;
        address _cToken = loopCToken[_asset];
        address[] memory cTokens = new address[](1);                                                                                 
        //  entering MArket with ctoken
        cTokens[0] = _cToken;
        uint[] memory errors = comptroller.enterMarkets(cTokens);
        require(errors[0] == 0);
    }

    /// @notice EXIT COMPOUND MARKET.
    /// @param _cToken Exiting market for asset

    function _exitCompMarket(address _cToken) public  {      
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Unauthorized");                                                                       
        uint256 errors = comptroller.exitMarket(_cToken);
        require(errors == 0,"Exit CMarket?");
    }
   
    /// @notice CLAIM COMP TOKEN.
    function _claimProtocol() public  {
        require(hasRole(LOOP_ADMIN_ROLE, msg.sender), "Unauthorized");
        comptroller.claimComp(address(this));

        // Do something with Comp Token Add to loan Pool (would prevent borrowing Comp)
    }

    /// @notice Get Loan Fees interfacable public
    /// @param amount the amount we to take the fees on
    /// @param user the account that is paying the fees
    /// @return fee for the account

    function getLoanFees(uint256 amount, address user) public view returns(uint256){ 
         uint256 fees;
        if(loopCompNftOwners[user] && balanceOf(user) > 0){
           fees = loanFee.div(2);
        }else{
            fees = loanFee;
        }
        return (amount.div(10000)).mul(fees);
    }

   ///////////////////////////////////////////////////////
   //                   LOOP DEFI NFT
   //              MINTABLE UNTIL : 

    /// @notice GET NFT Interafcable ADMIN
    /// will mint the NFT and Stake in Compound Pool

    function _getNFT(address _to) public payable whenNotPaused { 
        require(hasRole(LOOP_ADMIN_ROLE, msg.sender),"Unauthorized?");
        require(msg.value == initCompNftPrice,'Wrong Price');
        CEther cToken = CEther(cEther);
        uint256 balanceBefore = cToken.balanceOf(address(this));
        cToken.mint{value : msg.value }();
        require(!loopCompNftOwners[_to], 'Unique');
        mint(_to);
        loopCompNftOwners[_to] = true;
        uint256 balanceAfter = cToken.balanceOf(address(this));
        CompInitialEth = CompInitialEth.add(balanceAfter.sub(balanceBefore));


        // UPDATE REWARD POOL HERE
        // POOL = cETH Loop contract balance.sub(CompInitialEth)
        // CompInitialEth is locked in Compound.

        emit NftSold(msg.sender);
    }

    /// @notice ACCEPT ETHER

    receive() external payable {
        // nothing to do
    }    

    /// @notice SECURITY.

    /// @notice pause or unpause.
    /// @dev Security feature to use with Defender

    function pause() public override whenNotPaused onlyOwner{
   
        _pause();
    }
    
    function unpause() public override whenPaused onlyOwner {

        _unpause();
    }


}