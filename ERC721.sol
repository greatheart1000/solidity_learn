// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.1.0) (token/ERC721/ERC721.sol)

pragma solidity ^0.8.20;

import {IERC721} from "./IERC721.sol";
import {IERC721Metadata} from "./extensions/IERC721Metadata.sol";
import {ERC721Utils} from "./utils/ERC721Utils.sol";
import {Context} from "../../utils/Context.sol";
import {Strings} from "../../utils/Strings.sol";
import {IERC165, ERC165} from "../../utils/introspection/ERC165.sol";
import {IERC721Errors} from "../../interfaces/draft-IERC6093.sol";

/**
 * @dev Implementation of https://eips.ethereum.org/EIPS/eip-721[ERC-721] Non-Fungible Token Standard, including
 * the Metadata extension, but not including the Enumerable extension, which is available separately as
 * {ERC721Enumerable}.
 */
abstract contract ERC721 is Context, ERC165, IERC721, IERC721Metadata, IERC721Errors {
    using Strings for uint256;

    // Token name
    string private _name;

    // Token symbol 
    string private _symbol;

    mapping(uint256 tokenId => address) private _owners;

    mapping(address owner => uint256) private _balances;

    mapping(uint256 tokenId => address) private _tokenApprovals;

    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;

    /**
     * @dev Initializes the contract by setting a `name` and a `symbol` to the token collection.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    } 
    //初始化合约时设置代币集合的名称 (name_) 和符号 (symbol_)

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC721).interfaceId ||
            interfaceId == type(IERC721Metadata).interfaceId ||
            super.supportsInterface(interfaceId);
    }
//supportsInterface 作用: 检查合约是否支持特定的接口（如 IERC721 和 IERC721Metadata）。
    /// @inheritdoc IERC721
    function balanceOf(address owner) public view virtual returns (uint256) {
        if (owner == address(0)) {
            revert ERC721InvalidOwner(address(0));
        }
        return _balances[owner];
    }
    //查询余额 作用: 返回指定地址拥有的 NFT 数量 owner: 拥有者的地址。返回值: 拥有者的 NFT 数量
    /// @inheritdoc IERC721
    function ownerOf(uint256 tokenId) public view virtual returns (address) {
        return _requireOwned(tokenId);
    }  //返回指定 tokenId 的拥有者地址。 tokenId: NFT 的唯一标识符

    /// @inheritdoc IERC721Metadata
    function name() public view virtual returns (string memory) {
        return _name;
    } //获取代币名称

    /// @inheritdoc IERC721Metadata
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    } //获取代币符号

    /// @inheritdoc IERC721Metadata
    function tokenURI(uint256 tokenId) public view virtual returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString()) : "";
    } 

    /** 参数 tokenId: NFT 的唯一标识符   作用: 返回指定 tokenId 的元数据 URI
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal view virtual returns (string memory) {
        return "";
    } // 作用: 返回基础 URI，用于构建完整的 tokenURI

    /// @inheritdoc IERC721
    function approve(address to, uint256 tokenId) public virtual {
        _approve(to, tokenId, _msgSender());
    }  //作用: 将指定 tokenId 的批准权授予另一个地址。 参数: to: 被授权的地址。  tokenId: NFT 的唯一标识符

    /// @inheritdoc IERC721
    function getApproved(uint256 tokenId) public view virtual returns (address) {
        _requireOwned(tokenId);

        return _getApproved(tokenId);
    }  //查询批准状态  作用: 返回指定 tokenId 的被授权地址。参数:tokenId: NFT 的唯一标识符。  返回值: 被授权的地址

    /// @inheritdoc IERC721
    function setApprovalForAll(address operator, bool approved) public virtual {
        _setApprovalForAll(_msgSender(), operator, approved);
    } //设置全局批准 设置或取消对某个操作员的全局批准权限 参数 : operator: 操作员地址。 approved: 是否批准。

    /// @inheritdoc IERC721
    function isApprovedForAll(address owner, address operator) public view virtual returns (bool) {
        return _operatorApprovals[owner][operator];
    } //作用: 查询某地址是否对另一地址具有全局批准权限。参数:owner: 拥有者的地址。 operator: 操作员地址。 返回值: 是否批准

    /// @inheritdoc IERC721
    function transferFrom(address from, address to, uint256 tokenId) public virtual {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        // Setting an "auth" arguments enables the `_isAuthorized` check which verifies that the token exists
        // (from != 0). Therefore, it is not needed to verify that the return value is not 0 here.
        address previousOwner = _update(to, tokenId, _msgSender());
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    } //作用: 将指定 tokenId 的 NFT 从一个地址转移到另一个地址。参数: from: 当前拥有者的地址。 to: 新拥有者的地址。 tokenId: NFT 的唯一标识符。

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId) public {
        safeTransferFrom(from, to, tokenId, "");
    } //作用: 安全地将指定 tokenId 的 NFT 从一个地址转移到另一个地址，不带附加数据

    /// @inheritdoc IERC721
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual {
        transferFrom(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
    } //作用: 安全地将指定 tokenId 的 NFT 从一个地址转移到另一个地址，并附带额外的数据 

    /**
     * @dev Returns the owner of the `tokenId`. Does NOT revert if token doesn't exist
     *
     * IMPORTANT: Any overrides to this function that add ownership of tokens not tracked by the
     * core ERC-721 logic MUST be matched with the use of {_increaseBalance} to keep balances
     * consistent with ownership. The invariant to preserve is that for any address `a` the value returned by
     * `balanceOf(a)` must be equal to the number of tokens such that `_ownerOf(tokenId)` is `a`.
     */
    function _ownerOf(uint256 tokenId) internal view virtual returns (address) {
        return _owners[tokenId];
    } // 作用: 返回指定 tokenId 的拥有者地址

    /**
     * @dev Returns the approved address for `tokenId`. Returns 0 if `tokenId` is not minted.
     */
    function _getApproved(uint256 tokenId) internal view virtual returns (address) {
        return _tokenApprovals[tokenId];
    } //查询批准状态（内部） 作用: 返回指定 tokenId 的被授权地址。参数:tokenId: NFT 的唯一标识符。 返回值: 被授权的地址

    /**
     * @dev Returns whether `spender` is allowed to manage `owner`'s tokens, or `tokenId` in
     * particular (ignoring whether it is owned by `owner`).
     *
     * WARNING: This function assumes that `owner` is the actual owner of `tokenId` and does not verify this
     * assumption.
     */
    function _isAuthorized(address owner, address spender, uint256 tokenId) internal view virtual returns (bool) {
        return
            spender != address(0) &&
            (owner == spender || isApprovedForAll(owner, spender) || _getApproved(tokenId) == spender);
    } //检查授权状态（内部） 参数:owner: 拥有者的地址。 spender: 被授权的地址。 tokenId: NFT 的唯一标识符。 返回值: 是否授权。

    function _checkAuthorized(address owner, address spender, uint256 tokenId) internal view virtual {
        if (!_isAuthorized(owner, spender, tokenId)) {
            if (owner == address(0)) {
                revert ERC721NonexistentToken(tokenId);
            } else {
                revert ERC721InsufficientApproval(spender, tokenId);
            }
        }
    } //作用: 检查某个地址是否被授权管理指定 tokenId，如果没有授权则抛出异常

    /**
     * @dev Unsafe write access to the balances, used by extensions that "mint" tokens using an {ownerOf} override.
     *
     * NOTE: the value is limited to type(uint128).max. This protect against _balance overflow. It is unrealistic that
     * a uint256 would ever overflow from increments when these increments are bounded to uint128 values.
     *
     * WARNING: Increasing an account's balance using this function tends to be paired with an override of the
     * {_ownerOf} function to resolve the ownership of the corresponding tokens so that balances and ownership
     * remain consistent with one another.
     */
    function _increaseBalance(address account, uint128 value) internal virtual {
        unchecked {
            _balances[account] += value;
        }
    } //作用: 增加指定账户的 NFT 平衡。参数:account: 账户地址。 value: 增加的数量。

    /**
     * @dev Transfers `tokenId` from its current owner to `to`, or alternatively mints (or burns) if the current owner
     * (or `to`) is the zero address. Returns the owner of the `tokenId` before the update.
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that
     * `auth` is either the owner of the token, or approved to operate on the token (by the owner).
     *
     * Emits a {Transfer} event.
     *
     * NOTE: If overriding this function in a way that tracks balances, see also {_increaseBalance}.
     */
    function _update(address to, uint256 tokenId, address auth) internal virtual returns (address) {
        address from = _ownerOf(tokenId);

        // Perform (optional) operator check
        if (auth != address(0)) {
            _checkAuthorized(from, auth, tokenId);
        }

        // Execute the update
        if (from != address(0)) {
            // Clear approval. No need to re-authorize or emit the Approval event
            _approve(address(0), tokenId, address(0), false);

            unchecked {
                _balances[from] -= 1;
            }
        }

        if (to != address(0)) {
            unchecked {
                _balances[to] += 1;
            }
        }

        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);

        return from;
    }

    /**
    * 作用: 更新指定 tokenId 的所有权，并处理相关事件和平衡变化。
    *参数:
    *to: 新拥有者的地址。
    *tokenId: NFT 的唯一标识符。
    *auth: 授权地址（可选）。
    *返回值: 上一个拥有者的地址。
    * Emits a {Transfer} event.
    * 运行逻辑:
    *获取当前持有者 from。
    *如果提供了授权地址 auth，则调用 _checkAuthorized 函数检查该地址是否有权限操作 tokenId。
    *如果当前持有者 from 不为空：
    *清除对该 tokenId 的批准。
    *减少当前持有者的余额。
    *如果新持有者 to 不为空：
    *增加新持有者的余额。
    *更新 tokenId 的持有者为 to。
    *触发 Transfer 事件。
    *返回上一个持有者的地址 from
     */
    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner != address(0)) {
            revert ERC721InvalidSender(address(0));
        }
    }

    /**作用: 铸造一个新的 NFT 并分配给指定地址。参数:  to: 新拥有者的地址。 tokenId: NFT 的唯一标识符
    *作用: 铸造一个新的 NFT 并分配给指定地址。
    *参数:
    *to: 新拥有者的地址。
    *tokenId: NFT 的唯一标识符。
    **运行逻辑:
    *检查接收地址 to 是否为零地址，如果是，则抛出异常 ERC721InvalidReceiver。
    *调用 _update 函数将 tokenId 分配给 to，并记录之前的持有者 previousOwner。
    *如果 previousOwner 不为空，则表示 tokenId 已经存在，抛出异常 ERC721InvalidSender
     * @dev Mints `tokenId`, transfers it to `to` and checks for `to` acceptance.
     *
     * Requirements:
     *
     * - `tokenId` must not exist.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.

     */
    function _safeMint(address to, uint256 tokenId) internal {
        _safeMint(to, tokenId, "");
    } 

    /**
     * @dev Same as {xref-ERC721-_safeMint-address-uint256-}[`_safeMint`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeMint(address to, uint256 tokenId, bytes memory data) internal virtual {
        _mint(to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), address(0), to, tokenId, data);
    }
    
    /**
    *作用: 安全地铸造一个新的 NFT 并分配给指定地址，确保接收方知道如何处理 ERC-721 标准。
    *参数:
    *to: 新拥有者的地址。
    *tokenId: NFT 的唯一标识符。
    *data: 附加数据，用于传递给接收方。
    *运行逻辑:
    *调用 _mint 函数铸造并分配 tokenId 给 to。
    *调用 ERC721Utils.checkOnERC721Received 函数，确保如果 to 是智能合约，则其实现了 onERC721Received 方法，以防止代币被永久锁定
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     * This is an internal function that does not check if the sender is authorized to operate on the token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal {
        address previousOwner = _update(address(0), tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
    }

    /**作用: 销毁指定的 tokenId。
     *    参数:
     *    tokenId: NFT 的唯一标识符。
     *    运行逻辑:
     *    调用 _update 函数将 tokenId 的持有者设置为零地址。
     *    如果 previousOwner 为空，则表示 tokenId 不存在，抛出异常 ERC721NonexistentToken
     * @dev Transfers `tokenId` from `from` to `to`.
     *  As opposed to {transferFrom}, this imposes no restrictions on msg.sender.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     *
     * Emits a {Transfer} event.
     */
    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) {
            revert ERC721InvalidReceiver(address(0));
        }
        address previousOwner = _update(to, tokenId, address(0));
        if (previousOwner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        } else if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
    }

    /**
    * 作用: 将 tokenId 从 from 转移到 to。
    * 参数:
    * from: 当前持有者的地址。
    * to: 新持有者的地址。
    * tokenId: NFT 的唯一标识符。
    * 运行逻辑:
    * 检查接收地址 to 是否为零地址，如果是，则抛出异常 ERC721InvalidReceiver。
    * 调用 _update 函数将 tokenId 的持有者从 from 转移到 to，并记录之前的持有者 previousOwner。
    * 如果 previousOwner 为空，则表示 tokenId 不存在，抛出异常 ERC721NonexistentToken。
    * 如果 previousOwner 不等于 from，则表示 from 不是真正的持有者，抛出异常 ERC721IncorrectOwner。
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking that contract recipients
     * are aware of the ERC-721 standard to prevent tokens from being forever locked.
     *
     * `data` is additional data, it has no specified format and it is sent in call to `to`.
     *
     * This internal function is like {safeTransferFrom} in the sense that it invokes
     * {IERC721Receiver-onERC721Received} on the receiver, and can be used to e.g.
     * implement alternative mechanisms to perform token transfer, such as signature-based.
     *
     * Requirements:
     *
     * - `tokenId` token must exist and be owned by `from`.
     * - `to` cannot be the zero address.
     * - `from` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function _safeTransfer(address from, address to, uint256 tokenId) internal {
        _safeTransfer(from, to, tokenId, "");
    }

    /** 安全地将 tokenId 从 from 转移到 to，确保接收方知道如何处理 ERC-721 标准。
    *参数:
    *from: 当前持有者的地址。
    *to: 新持有者的地址。
    *tokenId: NFT 的唯一标识符。
    *data: 附加数据，用于传递给接收方。
    *运行逻辑:
    *调用 _transfer 函数将 tokenId 从 from 转移到 to。
    *调用 ERC721Utils.checkOnERC721Received 函数，确保如果 to 是智能合约，则其实现了 onERC721Received 方法，以防止代币被永久锁定。
     * @dev Same as {xref-ERC721-_safeTransfer-address-address-uint256-}[`_safeTransfer`], with an additional `data` parameter which is
     * forwarded in {IERC721Receiver-onERC721Received} to contract recipients.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, bytes memory data) internal virtual {
        _transfer(from, to, tokenId);
        ERC721Utils.checkOnERC721Received(_msgSender(), from, to, tokenId, data);
    }

    /**
     * @dev Approve `to` to operate on `tokenId`
     *
     * The `auth` argument is optional. If the value passed is non 0, then this function will check that `auth` is
     * either the owner of the token, or approved to operate on all tokens held by this owner.
     *
     * Emits an {Approval} event.
     *
     * Overrides to this logic should be done to the variant with an additional `bool emitEvent` argument.
     */
    function _approve(address to, uint256 tokenId, address auth) internal {
        _approve(to, tokenId, auth, true);
    }

    /**
     * @dev Variant of `_approve` with an optional flag to enable or disable the {Approval} event. The event is not
     * emitted in the context of transfers.
     */
    function _approve(address to, uint256 tokenId, address auth, bool emitEvent) internal virtual {
        // Avoid reading the owner unless necessary
        if (emitEvent || auth != address(0)) {
            address owner = _requireOwned(tokenId);

            // We do not use _isAuthorized because single-token approvals should not be able to call approve
            if (auth != address(0) && owner != auth && !isApprovedForAll(owner, auth)) {
                revert ERC721InvalidApprover(auth);
            }

            if (emitEvent) {
                emit Approval(owner, to, tokenId);
            }
        }

        _tokenApprovals[tokenId] = to;
    }

    /**
     *   作用: 授权 to 操作 tokenId。
     *   参数:
     *   to: 被授权的地址。
     *    tokenId: NFT 的唯一标识符。
     *   auth: 授权地址（可选）。
     *   emitEvent: 是否触发 Approval 事件。
     *   运行逻辑:
     *   如果需要触发事件或提供了授权地址 auth，则获取 tokenId 的持有者 owner。
     *   检查 auth 是否有权限授权 to 操作 tokenId。如果没有权限，则抛出异常 ERC721InvalidApprover。
     *   如果需要触发事件，则触发 Approval 事件。
     *   更新 tokenId 的批准地址为 to
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Requirements:
     * - operator can't be the address zero.
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        if (operator == address(0)) {
            revert ERC721InvalidOperator(operator);
        }
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**作用: 授权或取消对某个操作员的全局批准权限。
     * 参数:
     *  owner: 拥有者的地址。
     *   operator: 操作员地址。
     *  approved: 是否批准。
     *    运行逻辑:
     *    检查操作员地址 operator 是否为零地址，如果是，则抛出异常 ERC721InvalidOperator。
     *   更新 owner 对 operator 的全局批准状态为 approved。
     *  触发 ApprovalForAll 事件。
     * @dev Reverts if the `tokenId` doesn't have a current owner (it hasn't been minted, or it has been burned).
     * Returns the owner.
     *
     * Overrides to ownership logic should be done to {_ownerOf}.
     */
    function _requireOwned(uint256 tokenId) internal view returns (address) {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) {
            revert ERC721NonexistentToken(tokenId);
        }
        return owner;
    }
//作用: 查询并验证 tokenId 是否有持有者。参数:tokenId: NFT 的唯一标识符。 返回值: 持有者的地址。
//运行逻辑: 获取 tokenId 的持有者 owner。
//如果持有者为空，则表示 tokenId 不存在，抛出异常 ERC721NonexistentToken。
//返回持有者的地址 owner。
}
