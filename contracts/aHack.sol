// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

     /**
     * @notice The Loop Aave NFT
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

// Aave Interface
import "./interfaces/aave/AaveProtocolDataProvider.sol";
import "./interfaces/aave/ILendingPoolAddressesProvider.sol";
import "./interfaces/aave/ILendingPool.sol";
import "./interfaces/aave/WETHGateway.sol";
import "./interfaces/aave/AToken.sol";

contract aHack is Initializable, ERC721PresetMinterPauserAutoIdUpgradeable, OwnableUpgradeable {
    using SafeMathUpgradeable for uint256;

    string public version;
    bytes32 LOOP_ADMIN_ROLE;     
    address LOOP;
    uint256 maxAaveNftSupply;                  // maxNftSupply
    uint256 daiNftPrice;
    uint256 initialDai;                    

    WETHGateway weth;
    address WETH;
    address ETHER;
    address DAI;
    
    uint256 loanFee;
    AaveProtocolDataProvider IdataProvider;
    ILendingPoolAddressesProvider provider;
    address lendingPoolAddr;
    address wethGatewayAddr;
    address dataProvider;
    uint16 referral;


    // Loan Info
    bool public loan;           // set to true on borrow
    uint256 loanedAmount;       // loan info
    address loanedAsset;        // borowed asset
    uint256 balanceBeforeLoan;  // balance before loan
    
    mapping(address => mapping(address => uint256)) public avgIndex; // user => asset => amount
    mapping(address => address) public collaterals;       // token => aToken
    mapping(address => bool) aaveNftOwners;               // NFT Registery (unique per account)
    mapping(address => bool) public loopAaveMarket;       // Entered market on Aave
    mapping(address => uint256) public loanCumulatedFees; // for nft owners              
   
    event NftSold(address user); 

    function initialize(
      string memory name,
      string memory symbol,
      uint256 fees,
      string memory uri,
      address loopAdmin,
      ILendingPoolAddressesProvider _addressProvider
    ) public virtual initializer {
        __ERC721PresetMinterPauserAutoId_init(name, symbol, uri);
        __Ownable_init();
        _setupRole(LOOP_ADMIN_ROLE, loopAdmin);
   
        version = "1.0";
        daiNftPrice = 25000000000000000000; // 2,500 DAI
        loanFee = fees;
        wethGatewayAddr = 0xcc9a0B7c43DC2a5F023Bb9b738E45B0Ef6B06E04; 
        WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;      
        ETHER = address(0);
        DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;

        weth = WETHGateway(wethGatewayAddr);
        provider = _addressProvider;
        lendingPoolAddr = provider.getLendingPool();
        dataProvider = 0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d;
        IdataProvider = AaveProtocolDataProvider(dataProvider);
    }

   ///////////////////////////////////////////////////////
   //                   AAVE LOAN
   //

    // NOTE: The fees should be calculated here is the NFT give or not a bonus

    /// @notice BORROW Interfacable
    /// @param amount the amount we to take the fees on
    /// @param asset the account that is paying the fees

    function _borrow(uint256 amount, address asset) public whenNotPaused onlyOwner returns(uint256){ 
        require(hasRole(LOOP_ADMIN_ROLE, msg.sender), "Unauthorized?");
        require(!loan, 'Ongoing loan');

        address _aToken = collaterals[asset];
        ILendingPool lendingPool = ILendingPool(lendingPoolAddr);

        // check if we can borrow

        IERC20Upgradeable _asset = IERC20Upgradeable(asset);
        uint256 balBefore;
        uint256 balAfter;

        if (asset == ETHER) {
            balBefore = address(this).balance; // full balance
            IERC20Upgradeable collateral = IERC20Upgradeable(_aToken);
            collateral.approve(address(weth),amount);
            weth.withdrawETH(address(lendingPool),amount, msg.sender); 
            balAfter = address(this).balance; // should be smaller
        } else {
            balBefore = _asset.balanceOf(address(this));
            IERC20Upgradeable collateral = IERC20Upgradeable(_aToken);
            collateral.approve(address(lendingPool),amount);  
            lendingPool.withdraw(asset, amount, msg.sender);
            balAfter = _asset.balanceOf(address(this));
            _asset.transfer(msg.sender, balAfter.sub(balAfter));
        }

        require(balBefore.sub(balAfter) == amount, "Balance mismatch"); // if true, we have funds in the LOOP
        loan = true; // loan activated
        return 0;
    }

    /// @notice Repay Loop Aave Loan
    // register collateral address
    // 
    function _repay() public payable whenNotPaused onlyOwner returns(uint256){
        require(hasRole(LOOP_ADMIN_ROLE, msg.sender), "Unauthorized?");
        
        address _aToken = collaterals[loanedAsset];
   
        IERC20Upgradeable aToken = IERC20Upgradeable(_aToken);
        ILendingPool lendingPool = ILendingPool(lendingPoolAddr);

        uint256 balanceB = aToken.balanceOf(address(this)); // loans + fees

        if (loanedAsset == ETHER) {
            // wraps ether and gives Aave token
            weth.depositETH{value: msg.value}(address(lendingPool),address(this), referral);
        } else {
            IERC20Upgradeable underlying = IERC20Upgradeable(loanedAsset);
            underlying.approve(address(lendingPool), loanedAmount);
            lendingPool.deposit(loanedAsset, loanedAmount, address(this), referral);
        }

        uint256 balanceA = aToken.balanceOf(address(this));
        require(balanceA == balanceB.add(balanceB), "Balance mismatch"); // if true, we have funds in the LOOP

        return 0;
    }

     /// @notice returns the index required to keep track of gains
    /// @dev We only need to store the index
    /// @param _asset the asset address

    function getLiquidityIndex(address _asset) public view returns (uint256){
            if(_asset == ETHER){
            _asset = WETH;
        }
        uint256 liquidityIndex;
         (,,,,,,,liquidityIndex ,, ) = IdataProvider.getReserveData(_asset);
        return liquidityIndex;
    }


    function setCollaterals(address _asset, address _collateral) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Unauthorized?");
        collaterals[_asset] = _collateral;
    }

    /// @notice SET AAVE REFERALL CODE
    /// @param _code The referall code

    function setReferralCode(uint16 _code) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Unauthorized?");
        referral = _code;
    }
    /// @notice returns the balance of the user
    /// @dev balance should be returned even if paused
    /// @param _user the user address
    /// @param _asset the asset address

    function balanceOf(address _user, address _asset)
        public
        view
        returns (uint256)
    {
        if(avgIndex[_user][_asset] > 0){
            if(_asset == ETHER){
                return (avgIndex[_user][_asset].mul(getLiquidityIndex(WETH))).div(1e27);
            }
            else{
                return (avgIndex[_user][_asset].mul(getLiquidityIndex(_asset))).div(1e27);
            }
        }else{
          return 0;
        }
      
        
    }
   
    /// @notice CLAIM COMP TOKEN.
    function _claimAave() public onlyOwner {
        // aavetroller.claimAave(address(this));

        // Do something with Aave Token Add to loan Pool (would prevent borrowing Aave)
    }

    /// @notice Get Loan Fees interfacable public
    /// @param amount the amount we to take the fees on
    /// @param user the account that is paying the fees
    /// @return fee for the account

    function getLoanFees(uint256 amount, address user) public view returns(uint256){ 
        uint256 fee;
        if (!aaveNftOwners[user]) {
            fee =  loanFee; 
        } else if (aaveNftOwners[user]) {
            fee =  loanFee.div(2);
        }
        return amount.div(10000).mul(loanFee);
    }

   ///////////////////////////////////////////////////////
   //                   LOOP DEFI NFT
   //              MINTABLE UNTIL : 

    /**
     * @notice GET NFT Interfacable ADMIN
     * @dev will mint the NFT and Stake in Aave Pool
     * @param _to user receiving NFT
     */
    function _getNFT(address _to) public payable whenNotPaused { 
        require(hasRole(LOOP_ADMIN_ROLE, msg.sender),"Unauthorized?");
        
        address _aToken = collaterals[DAI]; // fetch asset
        IERC20Upgradeable aToken = IERC20Upgradeable(_aToken); // declare IERC(DAI) to call functions from
        ILendingPool lendingPool = ILendingPool(_aToken); // fetch lending pool of aToken
        IERC20Upgradeable dai = IERC20Upgradeable(DAI); // declare IERC(DAI) to call functions from

        uint256 balDaiBefore = dai.balanceOf(address(this)); // check Dai balance before
        uint256 balADaiBefore =  aToken.balanceOf(address(this)); // check aDai balance before

        dai.transferFrom(tx.origin, address(this), daiNftPrice); // move nftPrice to this address from caller
        lendingPool.deposit(DAI, daiNftPrice, address(this), referral); // deposit dai into this address

        uint256 balDaiAfter = dai.balanceOf(address(this)); // check Dai balance after
        uint256 balADaiAfter = dai.balanceOf(address(this)); // check aDai balance after
        require(balDaiBefore == balDaiAfter, "balance mismatch");

        uint256 aDaiStake = balADaiAfter.sub(balADaiBefore);
        avgIndex[address(this)][DAI] = avgIndex[address(this)][DAI].add(aDaiStake).div(getLiquidityIndex(DAI));

        daiNftPrice = daiNftPrice.add(balDaiAfter.sub(balDaiBefore));
        
        aaveNftOwners[_to] = true;
        mint(_to);

        // UPDATE REWARD POOL HERE
        // POOL = cETH Loop contract balance.sub(CompInitialEth)
        // CompInitialEth is locked in Compound.

        emit NftSold(msg.sender);
    }

    /**
     * @return returns the value that is earned from locking in this NFT contratc
     */
    function valueStake() public view returns(uint256) {
        if (avgIndex[address(this)][DAI] != 0) {
            return ((avgIndex[address(this)][DAI].mul(getLiquidityIndex(DAI))).div(1e27));
        }
        return 0;
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