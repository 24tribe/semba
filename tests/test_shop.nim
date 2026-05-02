import utils
import ../model_stable/shop


proc testGetShopProducts() =
  let ctx = getInMemorySembaCtx()
  
  let shopProducts = getShopProducts(ctx.db)
  doAssert(shopProducts.len > 0)


proc testSuiteShop*() =
  testGetShopProducts()