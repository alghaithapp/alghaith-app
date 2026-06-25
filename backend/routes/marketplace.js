const express = require('express');
const router = express.Router();
const {
  listShoppingStores,
  listRestaurantStores,
  listServiceStores,
  listCatalogProducts,
  listOfferCatalogProducts,
  getMarketplaceStats,
  listRealEstateListings,
} = require('../supabase_repo');
const {
  parseQueryValue,
} = require('./_middleware');

router.get('/shopping-stores', async (req, res) => {
  try {
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const rows = await listShoppingStores(subCategoryId);
    return res.json(rows);
  } catch (error) {
    console.error('list shopping-stores error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load shopping stores.' });
  }
});

router.get('/restaurant-stores', async (req, res) => {
  try {
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const rows = await listRestaurantStores(subCategoryId);
    return res.json(rows);
  } catch (error) {
    console.error('list restaurant-stores error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load restaurant stores.' });
  }
});

router.get('/service-stores', async (req, res) => {
  try {
    const serviceId = String(parseQueryValue(req.query.serviceId) || '').trim();
    const productCategory = String(parseQueryValue(req.query.productCategory) || serviceId).trim();
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const marketplaceCategory = String(
      parseQueryValue(req.query.marketplaceCategory) || ''
    ).trim();
    if (!serviceId) {
      return res.status(400).json({ message: 'serviceId is required.' });
    }
    const rows = await listServiceStores(
      serviceId,
      productCategory,
      subCategoryId,
      marketplaceCategory
    );
    return res.json(rows);
  } catch (error) {
    console.error('list service-stores error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load service stores.' });
  }
});

router.get('/catalog-products', async (req, res) => {
  try {
    const category = String(parseQueryValue(req.query.category) || '').trim();
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const rows = await listCatalogProducts(category, subCategoryId);
    return res.json(rows);
  } catch (error) {
    console.error('list catalog error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load catalog.' });
  }
});

router.get('/offer-catalog-products', async (req, res) => {
  try {
    const rows = await listOfferCatalogProducts();
    return res.json(rows);
  } catch (error) {
    console.error('list offers-catalog error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load offers catalog.' });
  }
});

router.get('/marketplace-stats', async (req, res) => {
  try {
    const rows = await getMarketplaceStats();
    return res.json(rows);
  } catch (error) {
    console.error('marketplace-stats error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load marketplace stats.' });
  }
});

router.get('/real-estate-listings', async (req, res) => {
  try {
    const subCategoryId = String(parseQueryValue(req.query.subCategoryId) || '').trim();
    const listingMode = String(parseQueryValue(req.query.listingMode) || '').trim();
    const neighborhood = String(parseQueryValue(req.query.neighborhood) || '').trim();
    const rows = await listRealEstateListings(subCategoryId, listingMode, neighborhood);
    return res.json(rows);
  } catch (error) {
    console.error('list real-estate-listings error:', error);
    return res.status(500).json({ message: error?.message || 'Failed to load real estate listings.' });
  }
});

module.exports = router;
