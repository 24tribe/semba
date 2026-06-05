import std/json
import std/options

import utils
import ../protojson
import ../model_stable/resources
import ../model_stable/shop
import ../model_stable/item
import ../model_stable/wallet


proc testGetShopProducts() =
  let ctx = getInMemorySembaCtx()
  
  let shopProducts = getShopProducts(ctx.db)
  doAssert(shopProducts.len > 0)


proc testShopPurchase() =
  var ctx = getInMemorySembaCtx()

  let walletBefore = getWallet(ctx.db)

  const enigmaticPieceId = 106

  upsertItem(ctx.db, Item(itemId: enigmaticPieceId, quantity: some(120)))

  let res = protoJsonTo(
    ctx.sembaCall("/shop/purchase", %*{"shopProductId": 4012001, "quantity": 2}),
    Option[ChangedResourcesResponse]
  )

  doAssert(res.isSome())

  let changedResources = res.get().changedResources

  # FIXME: "the exchangeable items have been updated"
  #[ let shopProductsStates = changedResources.shopProductStates.get(@[])

  doAssert(shopProductsStates.len == 1)
  doAssert(shopProductsStates[0].shopProductId == 4012001)
  doAssert(shopProductsStates[0].purchasedCount == 2) ]#

  let items = changedResources.items.get(@[])
  doAssert(items == [Item(itemId: enigmaticPieceId, quantity: some(20))])

  let walletAfter = getWallet(ctx.db)
  doAssert(walletAfter.free.get(0) == walletBefore.free.get(0) + 240)


proc testSuiteShop*() =
  testGetShopProducts()
  testShopPurchase()