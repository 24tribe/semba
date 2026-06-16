import std/json
import std/options

import ./utils
import ../../src/semba/protojson
import ../../src/semba/model_stable/resources
import ../../src/semba/model_stable/shop
import ../../src/semba/model_stable/item
import ../../src/semba/model_stable/wallet


proc testGetShopProducts() =
  let ctx = getInMemorySembaCtx()
  
  let shopProducts = getShopProducts(ctx.db)
  doAssert(shopProducts.len > 0)


proc testShopPurchase() =
  var ctx = getInMemorySembaCtx()

  let walletBefore = getWallet(ctx.db)

  const enigmaticPieceId = 106

  upsertItem(ctx.db, Item(itemId: enigmaticPieceId, quantity: 120))

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

  doAssert(changedResources.items == [Item(itemId: enigmaticPieceId, quantity: 20)])

  let walletAfter = getWallet(ctx.db)
  doAssert(walletAfter.free.get(0) == walletBefore.free.get(0) + 240)


proc testSuiteShop*(savesDir: string) =
  testGetShopProducts()
  testShopPurchase()