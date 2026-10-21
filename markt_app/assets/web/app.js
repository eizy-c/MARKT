/* ==========================================================================
   MARTK - Admin Panel POS & Gestión Integral (Engine JavaScript)
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {
  // --- PURGE LEGACY TEST DATA (Sistema en 0 y Tasa Actual) ---
  function purgeLegacyTestData() {
    try {
      // 1. Purgar tasas obsoletas guardadas en caché (< 850 Bs, ej: 798.33)
      const bcvSaved = localStorage.getItem('martk_bcv_rates');
      if (bcvSaved) {
        try {
          const parsed = JSON.parse(bcvSaved);
          if (parsed.bcvUsd && parsed.bcvUsd < 850) {
            localStorage.removeItem('martk_bcv_rates');
          }
        } catch (_) {
          localStorage.removeItem('martk_bcv_rates');
        }
      }

      // 2. Limpiar ajustes permanentes si contienen tasas antiguas o datos de prueba
      const settings = localStorage.getItem('martk_settings_permanent');
      if (settings) {
        try {
          const parsed = JSON.parse(settings);
          if (parsed.exchange) {
            if (parsed.exchange.bcvUsd && parsed.exchange.bcvUsd < 850) {
              parsed.exchange.bcvUsd = 881.88;
              if (parsed.exchange.mode === 'bcv-usd') parsed.exchange.rate = 881.88;
            }
            if (parsed.exchange.bcvEur && parsed.exchange.bcvEur < 900) {
              parsed.exchange.bcvEur = 988.97;
              if (parsed.exchange.mode === 'bcv-eur') parsed.exchange.rate = 988.97;
            }
          }
          if (settings.includes('PubliCraft') || settings.includes('24190824') || settings.includes('J-40918290-1') || settings.includes('798')) {
            localStorage.removeItem('martk_settings_permanent');
          } else {
            localStorage.setItem('martk_settings_permanent', JSON.stringify(parsed));
          }
        } catch (_) {
          localStorage.removeItem('martk_settings_permanent');
        }
      }

      const quotes = localStorage.getItem('martk_quotes');
      if (quotes && (quotes.includes('Boutique Velvet') || quotes.includes('798'))) {
        localStorage.removeItem('martk_quotes');
      }
      const projs = localStorage.getItem('martk_projects');
      if (projs && projs.includes('Boutique Velvet')) {
        localStorage.removeItem('martk_projects');
      }
      const prods = localStorage.getItem('martk_products');
      if (prods && (prods.includes('Aviso') || prods.includes('SRV-001'))) {
        localStorage.removeItem('martk_products');
      }
      const gal = localStorage.getItem('martk_gallery');
      if (gal && gal.includes('Burger Gourmet')) {
        localStorage.removeItem('martk_gallery');
      }
    } catch (e) {
      console.warn('Error purging legacy test data', e);
    }
  }


  // --- MODO 100% STANDALONE WEB & MOBILE (Sin Base de Datos / LocalStorage) ---

  const state = {
    activeView: 'view-pos',
    docType: 'venta', // 'venta' | 'ingreso' | 'egreso'
    folioCounter: 1,
    business: {
      name: '',
      id: '',
      address: '',
      phone: '',
      docTitle: 'FACTURA ELECTRÓNICA DE VENTA',
      docNumber: 'No. 001',
      currency: '$',
      category: 'general',
      logo: null
    },
    client: {
      name: '',
      id: '',
      phone: '',
      city: '',
      paymentForm: 'Pago Móvil',
      salesperson: '',
      date: new Date().toISOString().split('T')[0],
      time: new Date().toLocaleTimeString('es-ES', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: true })
    },
    exchange: {
      mode: 'bcv-usd', // 'bcv-usd' | 'bcv-eur' | 'custom'
      targetCurrency: 'USD',
      rate: 881.88,
      customRate: 881.88,
      showDual: true,
      bcvUsd: 881.88,
      bcvEur: 988.97,
      lastUpdated: '2026-10-20'
    },
    suiche: {
      bank: '0134',
      docType: 'J',
      docNumber: '',
      phone: '',
      amountMode: 'dynamic'
    },
    items: [],
    paymentDetails: {
      concept: '',
      amount: 0,
      ref: '',
      prevBalance: 0,
      newBalance: 0
    },
    totals: {
      subtotal: 0,
      taxRate: 0,
      taxAmount: 0,
      discount: 0,
      grandTotal: 0
    },
    options: {
      logoSize: 220,
      showBarcode: true,
      showQR: true,
      showSignature: true,
      showTaxTable: false,
      theme: 'theme-thermal',
      notes: 'Montos calculados según tasa oficial de referencia BCV.\nGracias por su compra.'
    },
    productsCatalog: [],
    servicesCatalog: [],
    materialsCatalog: [],
    suppliersCatalog: [],
    sellersCatalog: [],
    clientsCatalog: [],
    cashMovements: [],
    cuentasPorCobrar: [],
    cajaPeriodFilter: 'month',
    cajaTypeFilter: 'all',
    cxcStatusFilter: 'pending',
    reportPeriodFilter: 'month',
    history: [],
    cotizaciones: [],
    proyectos: [],
    galeria: [],
    activeQuote: null,
    quoteProfitMode: true,
    quoteStatusFilter: 'all',
    projectFilter: 'all',
    galleryCatFilter: 'all'
  };

  // --- FRONTEND SANITIZATION & AUTO-FORMATTING HELPERS ---
  function cleanInputText(val) {
    if (!val) return '';
    return String(val).replace(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/g, '').replace(/[ \t]+/g, ' ').trim();
  }

  function cleanIdentificacionInput(val) {
    if (!val) return '';
    return String(val).toUpperCase().replace(/[^A-Z0-9-.]/g, '').replace(/-+/g, '-').trim();
  }

  function cleanPhoneInput(val) {
    if (!val) return '';
    return String(val).replace(/[^0-9]/g, '');
  }

  function formatFolioNumber(num) {
    const padded = String(num).padStart(3, '0');
    if (state.docType === 'ingreso') return `No. RC-${padded}`;
    if (state.docType === 'egreso') return `No. CE-${padded}`;
    return `No. FES-${padded}`;
  }

  // --- ELEMENT REFERENCES ---
  const adminSidebar = document.getElementById('admin-sidebar');
  const sidebarOverlay = document.getElementById('sidebar-overlay');
  const btnToggleSidebar = document.getElementById('btn-toggle-sidebar');
  const btnCloseSidebarMobile = document.getElementById('btn-close-sidebar-mobile');
  
  const pageTitleText = document.getElementById('page-title-text');
  const pageSubtitleText = document.getElementById('page-subtitle-text');

  const navItems = document.querySelectorAll('.nav-item');
  const mobileNavBtns = document.querySelectorAll('.mobile-nav-btn');
  const appViews = document.querySelectorAll('.app-view');

  const sidebarBcvUsd = document.getElementById('sidebar-bcv-usd');
  const sidebarBcvEur = document.getElementById('sidebar-bcv-eur');
  const drawerBcvUsd = document.getElementById('drawer-bcv-usd');
  const drawerBcvEur = document.getElementById('drawer-bcv-eur');
  const btnSidebarFetchBcv = document.getElementById('btn-sidebar-fetch-bcv');
  const btnAjustesFetchBcv = document.getElementById('btn-ajustes-fetch-bcv');
  const ajustesBcvUsd = document.getElementById('ajustes-bcv-usd');
  const ajustesBcvEur = document.getElementById('ajustes-bcv-eur');
  const bcvLastUpdatedLbl = document.getElementById('bcv-last-updated-lbl');
  const sidebarHistoryCount = document.getElementById('sidebar-history-count');

  // Subtab elements
  const tabSubBtns = document.querySelectorAll('.tab-btn');
  const tabContents = document.querySelectorAll('.tab-content');
  const tabPersonText = document.getElementById('tab-person-text');
  const tabItemsText = document.getElementById('tab-items-text');
  const tabItemsIcon = document.getElementById('tab-items-icon');
  const sectionPersonTitle = document.getElementById('section-person-title');
  const btnNextStep1 = document.getElementById('btn-next-step-1');
  const btnNextStep2 = document.getElementById('btn-next-step-2');
  const btnPrevStep2 = document.getElementById('btn-prev-step-2');
  const btnPrevStep3 = document.getElementById('btn-prev-step-3');
  const btnNextStepText = document.getElementById('btn-next-step-text');
  const btnPrevStep2Text = document.getElementById('btn-prev-step-2-text');
  const btnPrevStep3Text = document.getElementById('btn-prev-step-3-text');
  const lblClientId = document.getElementById('lbl-client-id');
  const lblClientName = document.getElementById('lbl-client-name');

  // Form Controls in POS
  const docTypeBtns = document.querySelectorAll('.doc-type-btn');
  const docTypeTitleText = document.getElementById('doc-type-title-text');
  const inputClientName = document.getElementById('client-name');
  const inputClientId = document.getElementById('client-id');
  const btnSearchCedula = document.getElementById('btn-search-cedula');
  const inputClientPhone = document.getElementById('client-phone');
  const inputClientCity = document.getElementById('client-city');

  const selectPaymentForm = document.getElementById('payment-form');
  const customPaymentWrapper = document.getElementById('custom-payment-wrapper');
  const inputCustomPaymentName = document.getElementById('custom-payment-name');

  const selectRateMode = document.getElementById('select-rate-mode');
  const inputCustomRate = document.getElementById('input-custom-rate');
  const customRateWrapper = document.getElementById('custom-rate-wrapper');

  const inputSalesperson = document.getElementById('salesperson');
  const inputDocDate = document.getElementById('doc-date');
  const inputDocTime = document.getElementById('doc-time');
  const posDocNumber = document.getElementById('pos-doc-number');

  const sectionVentaItems = document.getElementById('section-venta-items');
  const sectionPaymentDetails = document.getElementById('section-payment-details');
  const itemsListContainer = document.getElementById('items-list-container');
  const btnAddItem = document.getElementById('btn-add-item');
  const btnOpenCatalogPicker = document.getElementById('btn-open-catalog-picker');
  const btnOpenSelectClientModal = document.getElementById('btn-open-select-client-modal');

  const inputTaxRate = document.getElementById('tax-rate');
  const inputDiscountAmount = document.getElementById('discount-amount');

  const inputPaymentConcept = document.getElementById('payment-concept');
  const inputPaymentAmount = document.getElementById('payment-amount');
  const inputPaymentRef = document.getElementById('payment-ref');
  const inputPrevBalance = document.getElementById('prev-balance');
  const inputNewBalance = document.getElementById('new-balance');

  // Suiche 7B Controls
  const selectSuicheBank = document.getElementById('suiche-bank');
  const selectSuicheDocType = document.getElementById('suiche-doc-type');
  const inputSuicheDocNumber = document.getElementById('suiche-doc-number');
  const inputSuichePhone = document.getElementById('suiche-phone');
  const selectSuicheAmountMode = document.getElementById('suiche-amount-mode');
  const suichePayloadText = document.getElementById('suiche-payload-text');

  // Ticket Preview elements
  const ticketCard = document.getElementById('ticket-container');
  const viewBizName = document.getElementById('view-biz-name');
  const viewBizId = document.getElementById('view-biz-id');
  const viewBizAddress = document.getElementById('view-biz-address');
  const viewBizPhone = document.getElementById('view-biz-phone');
  const ticketLogoImg = document.getElementById('ticket-logo-img');

  const viewDocBadge = document.getElementById('view-doc-badge');
  const viewDocTitle = document.getElementById('view-doc-title');
  const viewDocNumber = document.getElementById('view-doc-number');
  const barcodeWrapper = document.getElementById('barcode-wrapper');

  const viewDocDate = document.getElementById('view-doc-date');
  const viewDocTime = document.getElementById('view-doc-time');
  const viewLblPerson = document.getElementById('view-lbl-person');
  const viewClientName = document.getElementById('view-client-name');
  const viewClientId = document.getElementById('view-client-id');
  const viewClientCity = document.getElementById('view-client-city');
  const viewPaymentForm = document.getElementById('view-payment-form');
  const viewLblSalesperson = document.getElementById('view-lbl-salesperson');
  const viewSalesperson = document.getElementById('view-salesperson');

  const ticketItemsBlock = document.getElementById('ticket-items-block');
  const viewItemsBody = document.getElementById('view-items-body');

  const ticketPaymentReceiptBlock = document.getElementById('ticket-payment-receipt-block');
  const viewPaymentConcept = document.getElementById('view-payment-concept');
  const viewPaymentRefRow = document.getElementById('view-payment-ref-row');
  const viewPaymentRef = document.getElementById('view-payment-ref');
  const viewPrevBalanceRow = document.getElementById('view-prev-balance-row');
  const viewPrevBalance = document.getElementById('view-prev-balance');
  const viewNewBalanceRow = document.getElementById('view-new-balance-row');
  const viewNewBalance = document.getElementById('view-new-balance');

  const viewSubtotalRow = document.getElementById('view-subtotal-row');
  const viewSubtotal = document.getElementById('view-subtotal');
  const viewDiscountRow = document.getElementById('view-discount-row');
  const viewDiscount = document.getElementById('view-discount');
  const viewTaxRow = document.getElementById('view-tax-row');
  const viewTax = document.getElementById('view-tax');
  const viewTotalLbl = document.getElementById('view-total-lbl');
  const viewTotal = document.getElementById('view-total');
  const viewItemsCountRow = document.getElementById('view-items-count-row');
  const viewItemsCount = document.getElementById('view-items-count');

  const viewDualCurrencyWrapper = document.getElementById('view-dual-currency-wrapper');
  const viewDualTitle = document.getElementById('view-dual-title');
  const viewUsdTotal = document.getElementById('view-usd-total');
  const viewExchangeRateLbl = document.getElementById('view-exchange-rate-lbl');

  const viewTaxTableWrapper = document.getElementById('view-tax-table-wrapper');
  const viewTaxRateLbl = document.getElementById('view-tax-rate-lbl');
  const viewTaxBase = document.getElementById('view-tax-base');
  const viewTaxVal = document.getElementById('view-tax-val');

  const viewSignatureWrapper = document.getElementById('view-signature-wrapper');
  const viewSignatureText = document.getElementById('view-signature-text');
  const viewQrWrapper = document.getElementById('view-qr-wrapper');
  const viewQrCaption = document.getElementById('view-qr-caption');
  const viewNotesWrapper = document.getElementById('view-notes-wrapper');
  const viewNotesText = document.getElementById('view-notes-text');

  // Business & Settings elements
  const inputBizName = document.getElementById('biz-name');
  const inputBizId = document.getElementById('biz-id');
  const inputBizPhone = document.getElementById('biz-phone');
  const inputBizAddress = document.getElementById('biz-address');
  const inputFooterNotes = document.getElementById('footer-notes');
  const logoSizeRange = document.getElementById('logo-size-range');
  const logoSizeVal = document.getElementById('logo-size-val');

  const prefShowQr = document.getElementById('pref-show-qr');
  const prefShowBarcode = document.getElementById('pref-show-barcode');
  const prefShowSignature = document.getElementById('pref-show-signature');
  const prefShowTaxTable = document.getElementById('pref-show-tax-table');
  const themeCards = document.querySelectorAll('.theme-card');

  const inputDocNumber = document.getElementById('doc-number');
  const inputFolioCounter = document.getElementById('folio-counter');

  const inputLogo = document.getElementById('input-logo');
  const btnRemoveLogo = document.getElementById('btn-remove-logo');
  const logoPreview = document.getElementById('logo-preview');
  const btnSaveAllSettings = document.getElementById('btn-save-all-settings');

  // Products Section Elements
  const btnShowAddProductForm = document.getElementById('btn-show-add-product-form');
  const productFormBox = document.getElementById('product-form-box');
  const formProduct = document.getElementById('form-product');
  const btnCancelProduct = document.getElementById('btn-cancel-product');
  const searchProducts = document.getElementById('search-products');
  const productsTableBody = document.getElementById('products-table-body');

  // Clients Section Elements
  const btnShowAddClientForm = document.getElementById('btn-show-add-client-form');
  const clientFormBox = document.getElementById('client-form-box');
  const formClient = document.getElementById('form-client');
  const btnCancelClient = document.getElementById('btn-cancel-client');
  const searchClients = document.getElementById('search-clients');
  const clientsTableBody = document.getElementById('clients-table-body');

  // History Elements
  const searchHistory = document.getElementById('search-history');
  const historyTableBody = document.getElementById('history-table-body');
  const btnClearAllHistory = document.getElementById('btn-clear-all-history');

  // Modals & Actions
  const modalProductPicker = document.getElementById('modal-product-picker');
  const btnCloseProductPicker = document.getElementById('btn-close-product-picker');
  const pickerSearchProduct = document.getElementById('picker-search-product');
  const pickerProductList = document.getElementById('picker-product-list');

  const modalClientPicker = document.getElementById('modal-client-picker');
  const btnCloseClientPicker = document.getElementById('btn-close-client-picker');
  const pickerSearchClient = document.getElementById('picker-search-client');
  const pickerClientList = document.getElementById('picker-client-list');

  const btnSaveToHistory = document.getElementById('btn-save-to-history');
  const btnDownloadImg = document.getElementById('btn-download-img');
  const btnShareWhatsapp = document.getElementById('btn-share-whatsapp');
  const btnPrint = document.getElementById('btn-print');
  const btnQuickSample = document.getElementById('btn-quick-sample');
  const btnQuickReset = document.getElementById('btn-quick-reset');

  // --- INITIALIZATION ---
  function init() {
    purgeLegacyTestData();
    loadSavedSettingsAndBusiness();
    loadProductsFromStorage();
    loadServicesFromStorage();
    loadMaterialsFromStorage();
    loadSuppliersFromStorage();
    loadSellersFromStorage();
    loadClientsFromStorage();
    loadCashMovementsFromStorage();
    loadCxcFromStorage();
    loadHistoryFromStorage();
    loadCotizacionesFromStorage();
    loadProyectosFromStorage();
    loadGaleriaFromStorage();
    loadSavedBcvRates();
    setupNavigation();
    setupSubtabsSystem();
    setupDocTypeSelector();
    setupEventListeners();
    setupNewModulesEventListeners();
    setupPhases2to6EventListeners();
    setDefaultDateAndTime();
    renderItemsList();
    initActiveQuote();
    fetchBcvRatesFromApi();
    updateCalculationsAndPreview();
  }

  function setDefaultDateAndTime() {
    if (!inputDocDate.value) inputDocDate.value = state.client.date;
    if (!inputDocTime.value) inputDocTime.value = state.client.time;
  }

  // --- SUBTABS & STEP WIZARD NAVIGATION ---
  let maxReachedStep = 1;
  let switchSubtabByStepRef = null;

  function setupSubtabsSystem() {
    switchSubtabByStepRef = (targetStepNum) => {
      if (!state.options.showQR && targetStepNum === 3) {
        targetStepNum = 2;
      }

      if (targetStepNum > maxReachedStep) {
        maxReachedStep = targetStepNum;
      }

      const stepTabIds = ['tab-persona', 'tab-items', 'tab-opciones'];
      const targetTabId = stepTabIds[targetStepNum - 1];

      tabSubBtns.forEach((btn, idx) => {
        const stepNum = idx + 1;
        if (stepNum === targetStepNum) {
          btn.classList.add('active');
          btn.classList.remove('disabled');
        } else if (stepNum <= maxReachedStep) {
          btn.classList.remove('active');
          btn.classList.remove('disabled');
        } else {
          btn.classList.remove('active');
          btn.classList.add('disabled');
        }
      });

      tabContents.forEach(content => {
        if (content.id === targetTabId) {
          content.classList.add('active');
          content.classList.remove('hidden');
        } else {
          content.classList.remove('active');
          content.classList.add('hidden');
        }
      });

      if (targetTabId === 'tab-items') {
        if (state.docType === 'venta') {
          sectionVentaItems.classList.remove('hidden');
          sectionPaymentDetails.classList.add('hidden');
        } else {
          sectionVentaItems.classList.add('hidden');
          sectionPaymentDetails.classList.remove('hidden');
        }
      }
    };

    tabSubBtns.forEach((btn, idx) => {
      btn.addEventListener('click', () => {
        const stepNum = idx + 1;
        if (stepNum <= maxReachedStep) {
          switchSubtabByStepRef(stepNum);
        }
      });
    });

    if (btnNextStep1) btnNextStep1.addEventListener('click', () => switchSubtabByStepRef(2));
    if (btnNextStep2) {
      btnNextStep2.addEventListener('click', () => {
        if (state.options.showQR) {
          switchSubtabByStepRef(3);
        } else {
          saveCurrentReceiptToHistory();
        }
      });
    }
    if (btnPrevStep2) btnPrevStep2.addEventListener('click', () => switchSubtabByStepRef(1));
    if (btnPrevStep3) btnPrevStep3.addEventListener('click', () => switchSubtabByStepRef(2));

    switchSubtabByStepRef(1);
  }

  // --- NAVIGATION SYSTEM (SIDEBAR & VIEWS) ---
  function setupNavigation() {
    const switchView = (targetView) => {
      state.activeView = targetView;
      appViews.forEach(v => {
        if (v.id === targetView) v.classList.remove('hidden');
        else v.classList.add('hidden');
      });

      navItems.forEach(item => {
        if (item.getAttribute('data-view') === targetView) item.classList.add('active');
        else item.classList.remove('active');
      });

      document.querySelectorAll('.stitch-nav-item, .mobile-nav-btn').forEach(btn => {
        if (btn.getAttribute('data-view') === targetView) {
          btn.classList.add('text-secondary');
          btn.classList.remove('text-on-surface-variant');
        } else {
          btn.classList.remove('text-secondary');
          btn.classList.add('text-on-surface-variant');
        }
      });

      const currentViewTitle = document.getElementById('current-view-title');
      if (currentViewTitle) {
        if (targetView === 'view-pos') currentViewTitle.textContent = 'Terminal POS';
        else if (targetView === 'view-ticket') currentViewTitle.textContent = 'Ticket Oficial';
        else if (targetView === 'view-cotizaciones') currentViewTitle.textContent = 'Cotizaciones';
        else if (targetView === 'view-cotizacion-detalle') currentViewTitle.textContent = 'Presupuesto Formal';
        else if (targetView === 'view-proyectos') currentViewTitle.textContent = 'Proyectos';
        else if (targetView === 'view-galeria') currentViewTitle.textContent = 'Archivos CNC';
        else if (targetView === 'view-productos') currentViewTitle.textContent = 'Productos';
        else if (targetView === 'view-servicios') currentViewTitle.textContent = 'Servicios';
        else if (targetView === 'view-materiales') currentViewTitle.textContent = 'Materiales & Insumos';
        else if (targetView === 'view-proveedores') currentViewTitle.textContent = 'Proveedores';
        else if (targetView === 'view-vendedores') currentViewTitle.textContent = 'Vendedores & Comisiones';
        else if (targetView === 'view-clientes') currentViewTitle.textContent = 'Clientes';
        else if (targetView === 'view-historial') currentViewTitle.textContent = 'Historial';
        else if (targetView === 'view-ajustes') currentViewTitle.textContent = 'Mi Negocio';
        else if (targetView === 'view-changelog') currentViewTitle.textContent = 'Historial de Versiones';
        else if (targetView === 'view-caja') currentViewTitle.textContent = 'Libro de Caja';
        else if (targetView === 'view-cobranzas') currentViewTitle.textContent = 'Cuentas por Cobrar';
        else if (targetView === 'view-reportes') currentViewTitle.textContent = 'Analítica & Reportes';
        else if (targetView === 'view-privacidad') currentViewTitle.textContent = 'Políticas de Privacidad';
      }

      if (targetView === 'view-pos') {
        if (pageTitleText) pageTitleText.textContent = 'Terminal POS';
      } else if (targetView === 'view-ticket') {
        updateCalculationsAndPreview();
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } else if (targetView === 'view-cotizaciones') {
        if (pageTitleText) pageTitleText.textContent = 'Cotizaciones';
        renderQuotesHistory();
      } else if (targetView === 'view-cotizacion-detalle') {
        renderQuoteItemsTable();
        recalcQuoteTotals();
        setTimeout(() => initSignatureCanvas(), 100);
        window.scrollTo({ top: 0, behavior: 'smooth' });
      } else if (targetView === 'view-proyectos') {
        if (pageTitleText) pageTitleText.textContent = 'Proyectos';
        renderProjectsPipeline();
      } else if (targetView === 'view-galeria') {
        if (pageTitleText) pageTitleText.textContent = 'Archivos CNC';
        renderGallery();
      } else if (targetView === 'view-productos') {
        renderProductsTable();
      } else if (targetView === 'view-servicios') {
        if (pageTitleText) pageTitleText.textContent = 'Servicios';
        renderServicesTable();
      } else if (targetView === 'view-materiales') {
        if (pageTitleText) pageTitleText.textContent = 'Materiales & Insumos';
        renderMaterialsTable();
      } else if (targetView === 'view-proveedores') {
        if (pageTitleText) pageTitleText.textContent = 'Proveedores';
        renderSuppliersTable();
      } else if (targetView === 'view-vendedores') {
        if (pageTitleText) pageTitleText.textContent = 'Vendedores & Comisiones';
        renderVendorsTable();
      } else if (targetView === 'view-clientes') {
        renderClientsTable();
      } else if (targetView === 'view-historial') {
        renderHistoryTable();
      } else if (targetView === 'view-ajustes') {
        if (pageTitleText) pageTitleText.textContent = 'Mi Negocio';
      } else if (targetView === 'view-changelog') {
        if (pageTitleText) pageTitleText.textContent = 'Historial de Versiones';
      } else if (targetView === 'view-caja') {
        if (pageTitleText) pageTitleText.textContent = 'Libro de Caja';
        renderCajaView();
      } else if (targetView === 'view-cobranzas') {
        if (pageTitleText) pageTitleText.textContent = 'Cuentas por Cobrar';
        renderCxcView();
      } else if (targetView === 'view-reportes') {
        if (pageTitleText) pageTitleText.textContent = 'Analítica & Reportes';
        renderFinancialReport();
      } else if (targetView === 'view-privacidad') {
        if (pageTitleText) pageTitleText.textContent = 'Políticas de Privacidad';
      }

      if (adminSidebar) adminSidebar.classList.remove('mobile-open');
      if (sidebarOverlay) sidebarOverlay.classList.remove('mobile-open');
      const drawerEl = document.getElementById('system-drawer');
      const drawerOv = document.getElementById('drawer-overlay');
      if (drawerEl) drawerEl.classList.remove('drawer-open');
      if (drawerOv) drawerOv.classList.add('hidden');
    };

    navItems.forEach(item => {
      item.addEventListener('click', () => switchView(item.getAttribute('data-view')));
    });

    document.querySelectorAll('.stitch-nav-item, .mobile-nav-btn').forEach(btn => {
      btn.addEventListener('click', () => switchView(btn.getAttribute('data-view')));
    });

    const systemDrawer = document.getElementById('system-drawer');
    const drawerOverlay = document.getElementById('drawer-overlay');
    const btnToggleMenu = document.getElementById('btn-toggle-menu');
    const btnCloseDrawer = document.getElementById('btn-close-drawer');

    const openDrawer = () => {
      if (systemDrawer) systemDrawer.classList.add('drawer-open');
      if (drawerOverlay) drawerOverlay.classList.remove('hidden');
    };

    const closeDrawer = () => {
      if (systemDrawer) systemDrawer.classList.remove('drawer-open');
      if (drawerOverlay) drawerOverlay.classList.add('hidden');
    };

    if (btnToggleMenu) btnToggleMenu.addEventListener('click', openDrawer);
    if (btnCloseDrawer) btnCloseDrawer.addEventListener('click', closeDrawer);
    if (drawerOverlay) drawerOverlay.addEventListener('click', closeDrawer);

    document.querySelectorAll('.drawer-nav-item').forEach(btn => {
      btn.addEventListener('click', () => {
        const v = btn.getAttribute('data-view');
        if (v) switchView(v);
        closeDrawer();
      });
    });

    const btnOpenThermalModal = document.getElementById('btn-open-thermal-modal');
    if (btnOpenThermalModal) {
      btnOpenThermalModal.addEventListener('click', () => {
        switchView('view-ticket');
      });
    }

    const btnBackToPos = document.getElementById('btn-back-to-pos');
    if (btnBackToPos) {
      btnBackToPos.addEventListener('click', () => {
        switchView('view-pos');
      });
    }

    const btnBackToQuotes = document.getElementById('btn-back-to-quotes');
    if (btnBackToQuotes) {
      btnBackToQuotes.addEventListener('click', () => {
        switchView('view-cotizaciones');
      });
    }

    const btnNewQuote = document.getElementById('btn-new-quote');
    if (btnNewQuote) {
      btnNewQuote.addEventListener('click', () => {
        initActiveQuote();
        switchView('view-cotizacion-detalle');
      });
    }

    const btnBackChangelog = document.getElementById('btn-back-from-changelog');
    if (btnBackChangelog) {
      btnBackChangelog.addEventListener('click', () => switchView('view-ajustes'));
    }

    const btnBackPrivacidad = document.getElementById('btn-back-from-privacidad');
    if (btnBackPrivacidad) {
      btnBackPrivacidad.addEventListener('click', () => switchView('view-ajustes'));
    }

    const btnDrawerExportBackup = document.getElementById('btn-drawer-export-backup');
    if (btnDrawerExportBackup) {
      btnDrawerExportBackup.addEventListener('click', () => {
        exportDataBackup();
        closeDrawer();
      });
    }

    const btnDrawerImportBackup = document.getElementById('btn-drawer-import-backup');
    if (btnDrawerImportBackup) {
      btnDrawerImportBackup.addEventListener('click', () => {
        const fileInput = document.getElementById('input-import-backup');
        if (fileInput) fileInput.click();
        closeDrawer();
      });
    }

    if (btnToggleSidebar) {
      btnToggleSidebar.addEventListener('click', () => {
        adminSidebar.classList.toggle('mobile-open');
        sidebarOverlay.classList.toggle('mobile-open');
      });
    }

    if (btnCloseSidebarMobile) {
      btnCloseSidebarMobile.addEventListener('click', () => {
        adminSidebar.classList.remove('mobile-open');
        sidebarOverlay.classList.remove('mobile-open');
      });
    }

    if (sidebarOverlay) {
      sidebarOverlay.addEventListener('click', () => {
        adminSidebar.classList.remove('mobile-open');
        sidebarOverlay.classList.remove('mobile-open');
      });
    }
  }

  // --- CÉDULA / RIF LOOKUP & DIRECTORY ---
  function performCedulaLookup() {
    const rawVal = cleanIdentificacionInput(inputClientId.value);
    if (!rawVal) {
      showToast('Ingresa el número de Cédula o RIF para consultar.', 'info');
      return;
    }

    const cleanNum = rawVal.replace(/[^0-9]/g, '');

    const matchClient = state.clientsCatalog.find(c => (c.identificacion || '').replace(/[^0-9]/g, '') === cleanNum);
    if (matchClient) {
      state.client.name = matchClient.nombre;
      inputClientName.value = matchClient.nombre;
      if (matchClient.telefono) {
        state.client.phone = matchClient.telefono;
        inputClientPhone.value = matchClient.telefono;
      }
      if (matchClient.direccion) {
        state.client.city = matchClient.direccion;
        inputClientCity.value = matchClient.direccion;
      }
      updateCalculationsAndPreview();
      showToast(`Cliente encontrado en directorio: ${matchClient.nombre}`, 'success');
    } else {
      showToast('Cliente no registrado en directorio. Ingresa el nombre y se guardará automáticamente al emitir la factura.', 'info');
      inputClientName.focus();
    }
  }

  // --- BCV INTEGRATION & RATE SELECTOR ---
  function loadSavedBcvRates() {
    try {
      const saved = localStorage.getItem('martk_bcv_rates');
      if (saved) {
        const parsed = JSON.parse(saved);
        if (parsed.bcvUsd && typeof parsed.bcvUsd === 'number' && parsed.bcvUsd >= 850) {
          state.exchange.bcvUsd = parsed.bcvUsd;
        } else {
          state.exchange.bcvUsd = 881.88;
        }
        if (parsed.bcvEur && typeof parsed.bcvEur === 'number' && parsed.bcvEur >= 900) {
          state.exchange.bcvEur = parsed.bcvEur;
        } else {
          state.exchange.bcvEur = 988.97;
        }
        if (parsed.mode) state.exchange.mode = parsed.mode;
        if (parsed.customRate && parsed.customRate >= 800) state.exchange.customRate = parsed.customRate;
        if (parsed.lastUpdated) state.exchange.lastUpdated = parsed.lastUpdated;
      } else {
        state.exchange.bcvUsd = 881.88;
        state.exchange.bcvEur = 988.97;
      }
    } catch (e) {
      console.warn('Error loading saved BCV rates', e);
      state.exchange.bcvUsd = 881.88;
      state.exchange.bcvEur = 988.97;
    }
    syncBcvUiElements();
    updateRateOptionsDropdown();
    applyActiveRateMode();
  }

  function saveBcvRatesToStorage() {
    try {
      const data = {
        bcvUsd: state.exchange.bcvUsd,
        bcvEur: state.exchange.bcvEur,
        mode: state.exchange.mode,
        customRate: state.exchange.customRate,
        lastUpdated: state.exchange.lastUpdated || new Date().toISOString()
      };
      if (window.MarktNativeStorage) {
        window.MarktNativeStorage.setItem('martk_bcv_rates', data);
      } else {
        localStorage.setItem('martk_bcv_rates', JSON.stringify(data));
      }
    } catch (e) {
      console.warn('Error saving BCV rates', e);
    }
  }

  function syncBcvUiElements() {
    const usdStr = state.exchange.bcvUsd.toFixed(2);
    const eurStr = state.exchange.bcvEur.toFixed(2);

    if (sidebarBcvUsd) sidebarBcvUsd.textContent = usdStr;
    if (sidebarBcvEur) sidebarBcvEur.textContent = eurStr;
    if (drawerBcvUsd) drawerBcvUsd.textContent = `${usdStr} Bs.`;
    if (drawerBcvEur) drawerBcvEur.textContent = `${eurStr} Bs.`;
    if (ajustesBcvUsd) ajustesBcvUsd.value = usdStr;
    if (ajustesBcvEur) ajustesBcvEur.value = eurStr;

    if (bcvLastUpdatedLbl) {
      let dateText = 'Hoy (Al día)';
      if (state.exchange.lastUpdated) {
        try {
          const d = new Date(state.exchange.lastUpdated);
          dateText = d.toLocaleDateString('es-VE', { day: '2-digit', month: '2-digit', year: 'numeric' });
        } catch (_) {}
      }
      bcvLastUpdatedLbl.textContent = `Actualizado: ${dateText}`;
    }

    if (viewExchangeRateLbl) {
      if (state.exchange.mode === 'bcv-eur') {
        viewExchangeRateLbl.textContent = `Tasa BCV: ${eurStr} Bs./EUR`;
      } else {
        viewExchangeRateLbl.textContent = `Tasa BCV: ${usdStr} Bs./$`;
      }
    }
  }

  async function fetchBcvRatesFromApi(isManual = false) {
    if (sidebarBcvUsd) sidebarBcvUsd.textContent = '...';
    if (drawerBcvUsd) drawerBcvUsd.textContent = 'Consultando...';
    if (drawerBcvEur) drawerBcvEur.textContent = 'Consultando...';
    if (btnSidebarFetchBcv) btnSidebarFetchBcv.classList.add('animate-spin');
    if (btnAjustesFetchBcv) btnAjustesFetchBcv.classList.add('animate-spin');

    let updated = false;

    // Intento 1: cotizaciones generales dolarapi
    try {
      const res = await fetch('https://ve.dolarapi.com/v1/cotizaciones', { cache: 'no-store' });
      if (res.ok) {
        const data = await res.json();
        const usdObj = data.find(d => d.moneda === 'USD' && d.fuente === 'oficial');
        const eurObj = data.find(d => d.moneda === 'EUR' && d.fuente === 'oficial');

        if (usdObj && usdObj.promedio) {
          state.exchange.bcvUsd = parseFloat(usdObj.promedio);
          updated = true;
        }
        if (eurObj && eurObj.promedio) {
          state.exchange.bcvEur = parseFloat(eurObj.promedio);
          updated = true;
        }
        if (usdObj && usdObj.fechaActualizacion) {
          state.exchange.lastUpdated = usdObj.fechaActualizacion;
        }
      }
    } catch (e1) {
      console.warn('Fallo endpoint cotizaciones dolarapi, probando oficial individual:', e1);
    }

    // Intento 2: fallback oficial individual
    if (!updated) {
      try {
        const resUsd = await fetch('https://ve.dolarapi.com/v1/dolares/oficial', { cache: 'no-store' });
        if (resUsd.ok) {
          const usdData = await resUsd.json();
          if (usdData && usdData.promedio) {
            state.exchange.bcvUsd = parseFloat(usdData.promedio);
            updated = true;
            if (usdData.fechaActualizacion) state.exchange.lastUpdated = usdData.fechaActualizacion;
          }
        }
      } catch (e2) {
        console.warn('Fallo endpoint fallback individual oficial:', e2);
      }
    }

    if (state.exchange.bcvUsd < 850) {
      state.exchange.bcvUsd = 881.88;
      state.exchange.bcvEur = 988.97;
      state.exchange.lastUpdated = '2026-10-20';
    }

    if (btnSidebarFetchBcv) btnSidebarFetchBcv.classList.remove('animate-spin');
    if (btnAjustesFetchBcv) btnAjustesFetchBcv.classList.remove('animate-spin');

    syncBcvUiElements();
    updateRateOptionsDropdown();
    applyActiveRateMode();
    updateCalculationsAndPreview();
    saveBcvRatesToStorage();

    if (updated) {
      showToast(`Tasas BCV actualizadas al día: Dólar ${state.exchange.bcvUsd.toFixed(2)} Bs. | Euro ${state.exchange.bcvEur.toFixed(2)} Bs.`, 'success');
    } else {
      if (isManual) {
        showToast(`No se pudo conectar a la API BCV. Se mantiene la última tasa guardada: ${state.exchange.bcvUsd.toFixed(2)} Bs.`, 'warning');
      }
    }
  }

  function updateRateOptionsDropdown() {
    if (!selectRateMode) return;
    const optUsd = selectRateMode.querySelector('option[value="bcv-usd"]');
    const optEur = selectRateMode.querySelector('option[value="bcv-eur"]');

    if (optUsd) optUsd.textContent = `Tasa Oficial BCV Dólar ($) - [ ${state.exchange.bcvUsd.toFixed(2)} Bs. ]`;
    if (optEur) optEur.textContent = `Tasa Oficial BCV Euro (€) - [ ${state.exchange.bcvEur.toFixed(2)} Bs. ]`;
  }

  function applyActiveRateMode() {
    const mode = state.exchange.mode || 'bcv-usd';
    if (selectRateMode) selectRateMode.value = mode;

    const customWrapper = document.getElementById('custom-rate-wrapper');
    if (customWrapper) {
      if (mode === 'custom') {
        customWrapper.classList.remove('hidden');
      } else {
        customWrapper.classList.add('hidden');
      }
    }

    if (mode === 'bcv-usd') {
      state.exchange.rate = state.exchange.bcvUsd;
      if (inputCustomRate) {
        inputCustomRate.value = state.exchange.bcvUsd.toFixed(2);
        inputCustomRate.disabled = true;
      }
    } else if (mode === 'bcv-eur') {
      state.exchange.rate = state.exchange.bcvEur;
      if (inputCustomRate) {
        inputCustomRate.value = state.exchange.bcvEur.toFixed(2);
        inputCustomRate.disabled = true;
      }
    } else if (mode === 'custom') {
      if (inputCustomRate) {
        inputCustomRate.disabled = false;
        const customVal = parseFloat(inputCustomRate.value);
        if (customVal && customVal > 0) {
          state.exchange.customRate = customVal;
          state.exchange.rate = customVal;
        } else {
          state.exchange.rate = state.exchange.customRate || state.exchange.bcvUsd;
          inputCustomRate.value = state.exchange.rate.toFixed(2);
        }
      }
    }
  }

  if (btnSidebarFetchBcv) btnSidebarFetchBcv.addEventListener('click', () => fetchBcvRatesFromApi(true));
  if (btnAjustesFetchBcv) btnAjustesFetchBcv.addEventListener('click', () => fetchBcvRatesFromApi(true));

  if (ajustesBcvUsd) {
    ajustesBcvUsd.addEventListener('input', (e) => {
      const val = parseFloat(e.target.value);
      if (val && val > 0) {
        state.exchange.bcvUsd = val;
        if (state.exchange.mode === 'bcv-usd') state.exchange.rate = val;
        syncBcvUiElements();
        updateRateOptionsDropdown();
        applyActiveRateMode();
        updateCalculationsAndPreview();
        saveBcvRatesToStorage();
      }
    });
  }

  if (ajustesBcvEur) {
    ajustesBcvEur.addEventListener('input', (e) => {
      const val = parseFloat(e.target.value);
      if (val && val > 0) {
        state.exchange.bcvEur = val;
        if (state.exchange.mode === 'bcv-eur') state.exchange.rate = val;
        syncBcvUiElements();
        updateRateOptionsDropdown();
        applyActiveRateMode();
        updateCalculationsAndPreview();
        saveBcvRatesToStorage();
      }
    });
  }

  if (sidebarBcvUsd) {
    sidebarBcvUsd.style.cursor = 'pointer';
    sidebarBcvUsd.addEventListener('click', () => {
      state.exchange.mode = 'bcv-usd';
      applyActiveRateMode();
      autoSaveSettings();
      updateCalculationsAndPreview();
      showToast(`Tasa cambiada a BCV Dólar ($): ${state.exchange.bcvUsd.toFixed(2)} Bs.`, 'info');
    });
  }

  if (sidebarBcvEur) {
    sidebarBcvEur.style.cursor = 'pointer';
    sidebarBcvEur.addEventListener('click', () => {
      state.exchange.mode = 'bcv-eur';
      applyActiveRateMode();
      autoSaveSettings();
      updateCalculationsAndPreview();
      showToast(`Tasa cambiada a BCV Euro (€): ${state.exchange.bcvEur.toFixed(2)} Bs.`, 'info');
    });
  }

  if (drawerBcvUsd) {
    drawerBcvUsd.style.cursor = 'pointer';
    drawerBcvUsd.addEventListener('click', () => {
      state.exchange.mode = 'bcv-usd';
      applyActiveRateMode();
      autoSaveSettings();
      updateCalculationsAndPreview();
      showToast(`Tasa cambiada a BCV Dólar ($): ${state.exchange.bcvUsd.toFixed(2)} Bs.`, 'info');
    });
  }

  if (drawerBcvEur) {
    drawerBcvEur.style.cursor = 'pointer';
    drawerBcvEur.addEventListener('click', () => {
      state.exchange.mode = 'bcv-eur';
      applyActiveRateMode();
      autoSaveSettings();
      updateCalculationsAndPreview();
      showToast(`Tasa cambiada a BCV Euro (€): ${state.exchange.bcvEur.toFixed(2)} Bs.`, 'info');
    });
  }

  // --- DOCUMENT TYPE SELECTOR SWITCHING ---
  function setupDocTypeSelector() {
    docTypeBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        docTypeBtns.forEach(b => {
          b.classList.remove('active', 'bg-surface-container-high', 'text-secondary', 'shadow-sm', 'font-bold');
          b.classList.add('text-on-surface-variant', 'bg-surface-container-lowest', 'border', 'border-surface-container');
        });
        btn.classList.remove('text-on-surface-variant', 'bg-surface-container-lowest', 'border', 'border-surface-container');
        btn.classList.add('active', 'bg-surface-container-high', 'text-secondary', 'shadow-sm', 'font-bold');

        const type = btn.getAttribute('data-doctype') || btn.getAttribute('data-type') || 'venta';
        setDocumentType(type);
        updateCalculationsAndPreview();
        showToast(`Documento cambiado a: ${docTypeTitleText ? docTypeTitleText.textContent : type.toUpperCase()}`, 'info');
      });
    });
  }

  function setDocumentType(type) {
    state.docType = type || 'venta';

    if (state.docType === 'venta') {
      if (docTypeTitleText) docTypeTitleText.textContent = 'Factura de Venta';
      state.business.docTitle = 'FACTURA DE VENTA';
      if (sectionVentaItems) sectionVentaItems.classList.remove('hidden');
      if (sectionPaymentDetails) sectionPaymentDetails.classList.add('hidden');
      if (sectionPersonTitle) sectionPersonTitle.textContent = 'Cliente / Receptor';
      if (lblClientName) lblClientName.textContent = 'Nombre del Cliente / Razón Social *';
    } else if (state.docType === 'ingreso') {
      if (docTypeTitleText) docTypeTitleText.textContent = 'Recibo de Caja';
      state.business.docTitle = 'RECIBO DE CAJA';
      if (sectionVentaItems) sectionVentaItems.classList.add('hidden');
      if (sectionPaymentDetails) sectionPaymentDetails.classList.remove('hidden');
      if (sectionPersonTitle) sectionPersonTitle.textContent = 'Datos del Pagador / Cliente';
      if (lblClientName) lblClientName.textContent = 'Recibido de *';
    } else if (state.docType === 'egreso') {
      if (docTypeTitleText) docTypeTitleText.textContent = 'Comprobante de Egreso';
      state.business.docTitle = 'COMPROBANTE DE EGRESO';
      if (sectionVentaItems) sectionVentaItems.classList.add('hidden');
      if (sectionPaymentDetails) sectionPaymentDetails.classList.remove('hidden');
      if (sectionPersonTitle) sectionPersonTitle.textContent = 'Datos del Beneficiario';
      if (lblClientName) lblClientName.textContent = 'Pagado a / Beneficiario *';
    }

    state.business.docNumber = formatFolioNumber(state.folioCounter);
    if (posDocNumber) posDocNumber.textContent = state.business.docNumber;
    if (inputDocNumber) inputDocNumber.value = state.business.docNumber;

    updateCalculationsAndPreview();
  }

  // --- EVENT LISTENERS WITH AUTOMATIC SANITIZATION ---
  function setupEventListeners() {
    const btnClearPosClient = document.getElementById('btn-clear-pos-client');
    if (btnClearPosClient) {
      btnClearPosClient.addEventListener('click', () => {
        state.client.name = '';
        state.client.id = '';
        state.client.phone = '';
        state.client.city = '';
        if (inputClientName) inputClientName.value = '';
        if (inputClientId) inputClientId.value = '';
        if (inputClientPhone) inputClientPhone.value = '';
        if (inputClientCity) inputClientCity.value = '';
        updateCalculationsAndPreview();
        showToast('Cliente restablecido a Mostrador.', 'info');
      });
    }

    inputClientName.addEventListener('input', e => { state.client.name = cleanInputText(e.target.value); updateCalculationsAndPreview(); });
    inputClientName.addEventListener('blur', e => { e.target.value = cleanInputText(e.target.value); });

    inputClientId.addEventListener('input', e => { 
      const cleanVal = cleanIdentificacionInput(e.target.value);
      state.client.id = cleanVal; 
      e.target.value = cleanVal;
      updateCalculationsAndPreview(); 
    });
    inputClientId.addEventListener('keyup', e => { if (e.key === 'Enter') performCedulaLookup(); });
    if (btnSearchCedula) btnSearchCedula.addEventListener('click', performCedulaLookup);

    inputClientPhone.addEventListener('input', e => { 
      const cleanVal = cleanPhoneInput(e.target.value);
      state.client.phone = cleanVal; 
      e.target.value = cleanVal;
    });

    inputClientCity.addEventListener('input', e => { state.client.city = cleanInputText(e.target.value); updateCalculationsAndPreview(); });
    inputClientCity.addEventListener('blur', e => { e.target.value = cleanInputText(e.target.value); });

    selectPaymentForm.addEventListener('change', e => {
      if (e.target.value === 'custom') {
        customPaymentWrapper.classList.remove('hidden');
        state.client.paymentForm = cleanInputText(inputCustomPaymentName.value) || 'Otro';
      } else {
        customPaymentWrapper.classList.add('hidden');
        state.client.paymentForm = e.target.value;
      }
      updateCalculationsAndPreview();
    });

    inputCustomPaymentName.addEventListener('input', e => {
      if (selectPaymentForm.value === 'custom') {
        state.client.paymentForm = cleanInputText(e.target.value) || 'Otro';
        updateCalculationsAndPreview();
      }
    });

    selectRateMode.addEventListener('change', e => {
      state.exchange.mode = e.target.value;
      applyActiveRateMode();
      autoSaveSettings();
      updateCalculationsAndPreview();
    });

    inputCustomRate.addEventListener('input', e => {
      if (state.exchange.mode === 'custom') {
        const val = parseFloat(e.target.value) || 1;
        state.exchange.customRate = val;
        state.exchange.rate = val;
        autoSaveSettings();
        updateCalculationsAndPreview();
      }
    });

    inputSalesperson.addEventListener('input', e => { state.client.salesperson = cleanInputText(e.target.value); updateCalculationsAndPreview(); });
    inputDocDate.addEventListener('change', e => { state.client.date = e.target.value; updateCalculationsAndPreview(); });
    inputDocTime.addEventListener('input', e => { state.client.time = e.target.value; updateCalculationsAndPreview(); });

    inputTaxRate.addEventListener('input', e => { state.totals.taxRate = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });
    inputDiscountAmount.addEventListener('input', e => { state.totals.discount = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });

    inputPaymentConcept.addEventListener('input', e => { state.paymentDetails.concept = cleanInputText(e.target.value); updateCalculationsAndPreview(); });
    inputPaymentAmount.addEventListener('input', e => { state.paymentDetails.amount = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });
    inputPaymentRef.addEventListener('input', e => { state.paymentDetails.ref = cleanInputText(e.target.value); updateCalculationsAndPreview(); });
    inputPrevBalance.addEventListener('input', e => { state.paymentDetails.prevBalance = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });
    inputNewBalance.addEventListener('input', e => { state.paymentDetails.newBalance = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });

    selectSuicheBank.addEventListener('change', e => { state.suiche.bank = e.target.value; autoSaveSettings(); updateCalculationsAndPreview(); });
    selectSuicheDocType.addEventListener('change', e => { state.suiche.docType = e.target.value; autoSaveSettings(); updateCalculationsAndPreview(); });
    inputSuicheDocNumber.addEventListener('input', e => { 
      const cleanVal = cleanPhoneInput(e.target.value);
      state.suiche.docNumber = cleanVal; 
      e.target.value = cleanVal;
      autoSaveSettings(); 
      updateCalculationsAndPreview(); 
    });
    inputSuichePhone.addEventListener('input', e => { 
      const cleanVal = cleanPhoneInput(e.target.value);
      state.suiche.phone = cleanVal; 
      e.target.value = cleanVal;
      autoSaveSettings(); 
      updateCalculationsAndPreview(); 
    });
    selectSuicheAmountMode.addEventListener('change', e => { state.suiche.amountMode = e.target.value; autoSaveSettings(); updateCalculationsAndPreview(); });

    inputBizName.addEventListener('input', e => { state.business.name = cleanInputText(e.target.value); autoSaveSettings(); updateCalculationsAndPreview(); });
    inputBizId.addEventListener('input', e => { state.business.id = cleanIdentificacionInput(e.target.value); autoSaveSettings(); updateCalculationsAndPreview(); });
    inputBizPhone.addEventListener('input', e => { state.business.phone = cleanInputText(e.target.value); autoSaveSettings(); updateCalculationsAndPreview(); });
    inputBizAddress.addEventListener('input', e => { state.business.address = cleanInputText(e.target.value); autoSaveSettings(); updateCalculationsAndPreview(); });
    inputFooterNotes.addEventListener('input', e => { state.options.notes = cleanInputText(e.target.value); autoSaveSettings(); updateCalculationsAndPreview(); });

    logoSizeRange.addEventListener('input', e => {
      const val = parseInt(e.target.value) || 220;
      state.options.logoSize = val;
      logoSizeVal.textContent = `${val} px`;
      autoSaveSettings();
      updateCalculationsAndPreview();
    });

    prefShowQr.addEventListener('change', e => { 
      state.options.showQR = e.target.checked; 
      autoSaveSettings(true); 
      updateCalculationsAndPreview(); 
    });
    prefShowBarcode.addEventListener('change', e => { state.options.showBarcode = e.target.checked; autoSaveSettings(true); updateCalculationsAndPreview(); });
    prefShowSignature.addEventListener('change', e => { state.options.showSignature = e.target.checked; autoSaveSettings(true); updateCalculationsAndPreview(); });
    prefShowTaxTable.addEventListener('change', e => { state.options.showTaxTable = e.target.checked; autoSaveSettings(true); updateCalculationsAndPreview(); });

    themeCards.forEach(card => {
      card.addEventListener('click', () => {
        themeCards.forEach(c => c.classList.remove('active'));
        card.classList.add('active');
        const theme = card.getAttribute('data-theme');
        state.options.theme = theme;
        ticketCard.className = `ticket-card ${state.options.theme}`;
        autoSaveSettings(true);
      });
    });

    inputDocNumber.addEventListener('input', e => { state.business.docNumber = cleanInputText(e.target.value); updateCalculationsAndPreview(); });
    inputFolioCounter.addEventListener('input', e => {
      const val = parseInt(e.target.value) || 1;
      state.folioCounter = val;
      state.business.docNumber = formatFolioNumber(val);
      if (posDocNumber) posDocNumber.textContent = state.business.docNumber;
      if (inputDocNumber) inputDocNumber.value = state.business.docNumber;
      updateCalculationsAndPreview();
    });

    if (inputLogo) inputLogo.addEventListener('change', handleLogoUpload);
    if (logoPreview) {
      logoPreview.addEventListener('click', () => {
        if (inputLogo) inputLogo.click();
      });
    }
    const btnPasteLogo = document.getElementById('btn-paste-logo');
    if (btnPasteLogo) {
      btnPasteLogo.addEventListener('click', () => {
        const url = prompt('Ingresa la URL pública o Base64 de la imagen de tu logo:');
        if (url && url.trim()) {
          applyLogoToStateAndUI(url.trim());
          showToast('Logo asignado correctamente.', 'success');
        }
      });
    }
    if (btnRemoveLogo) btnRemoveLogo.addEventListener('click', handleLogoRemove);
    if (btnSaveAllSettings) btnSaveAllSettings.addEventListener('click', () => autoSaveSettings(true));

    btnAddItem.addEventListener('click', () => {
      state.items.push({
        id: Date.now().toString(),
        cant: 1,
        desc: '',
        subtext: '',
        taxRate: 0,
        unitPrice: 0
      });
      renderItemsList();
      updateCalculationsAndPreview();
    });

    btnOpenCatalogPicker.addEventListener('click', openProductPickerModal);
    btnCloseProductPicker.addEventListener('click', () => modalProductPicker.classList.add('hidden'));
    if (pickerSearchProduct) pickerSearchProduct.addEventListener('input', renderProductPickerGrid);

    btnOpenSelectClientModal.addEventListener('click', openClientPickerModal);
    btnCloseClientPicker.addEventListener('click', () => modalClientPicker.classList.add('hidden'));
    if (pickerSearchClient) pickerSearchClient.addEventListener('input', renderClientPickerList);

    btnShowAddProductForm.addEventListener('click', () => {
      formProduct.reset();
      document.getElementById('prod-id').value = '';
      productFormBox.classList.remove('hidden');
    });
    btnCancelProduct.addEventListener('click', () => productFormBox.classList.add('hidden'));
    formProduct.addEventListener('submit', handleSaveProduct);
    if (searchProducts) searchProducts.addEventListener('input', renderProductsTable);

    btnShowAddClientForm.addEventListener('click', () => {
      formClient.reset();
      clientFormBox.classList.remove('hidden');
    });
    btnCancelClient.addEventListener('click', () => clientFormBox.classList.add('hidden'));
    formClient.addEventListener('submit', handleSaveClient);
    if (searchClients) searchClients.addEventListener('input', renderClientsTable);

    if (searchHistory) searchHistory.addEventListener('input', renderHistoryTable);
    btnClearAllHistory.addEventListener('click', clearAllHistory);

    btnSaveToHistory.addEventListener('click', saveCurrentReceiptToHistory);
    btnDownloadImg.addEventListener('click', downloadTicketAsImage);
    btnShareWhatsapp.addEventListener('click', shareViaWhatsapp);
    btnPrint.addEventListener('click', () => window.print());

    btnQuickSample.addEventListener('click', loadSampleData);
    btnQuickReset.addEventListener('click', resetForm);

    // Copia de Seguridad y Migración
    const btnExportBackup = document.getElementById('btn-export-backup');
    const btnImportBackup = document.getElementById('btn-import-backup');
    const inputImportBackup = document.getElementById('input-import-backup');
    const btnResetFactory = document.getElementById('btn-reset-factory');

    if (btnExportBackup) btnExportBackup.addEventListener('click', exportDataBackup);
    if (btnImportBackup && inputImportBackup) {
      btnImportBackup.addEventListener('click', () => inputImportBackup.click());
      inputImportBackup.addEventListener('change', e => {
        if (e.target.files && e.target.files[0]) {
          importDataBackup(e.target.files[0]);
          inputImportBackup.value = '';
        }
      });
    }
    if (btnResetFactory) btnResetFactory.addEventListener('click', resetToFactoryDefaults);
  }

  // --- AUTO-SAVE SETTINGS HELPER ---
  function autoSaveSettings(showNotification = false) {
    state.business.name = cleanInputText(inputBizName.value);
    state.business.id = cleanIdentificacionInput(inputBizId.value);
    state.business.phone = cleanInputText(inputBizPhone.value);
    state.business.address = cleanInputText(inputBizAddress.value);
    const selectBizCat = document.getElementById('biz-category');
    if (selectBizCat) state.business.category = selectBizCat.value;
    state.options.notes = cleanInputText(inputFooterNotes.value);

    state.options.logoSize = parseInt(logoSizeRange.value) || 220;
    state.options.showQR = prefShowQr.checked;
    state.options.showBarcode = prefShowBarcode.checked;
    state.options.showSignature = prefShowSignature.checked;
    state.options.showTaxTable = prefShowTaxTable.checked;

    const activeThemeBtn = document.querySelector('.theme-card.active');
    if (activeThemeBtn) {
      state.options.theme = activeThemeBtn.getAttribute('data-theme');
      ticketCard.className = `ticket-card ${state.options.theme}`;
    }

    const settingsObj = {
      business: state.business,
      exchange: state.exchange,
      suiche: state.suiche,
      options: state.options
    };

    if (window.MarktNativeStorage) {
      window.MarktNativeStorage.setItem('martk_settings_permanent', settingsObj);
    } else {
      localStorage.setItem('martk_settings_permanent', JSON.stringify(settingsObj));
    }
    if (showNotification) showToast('Ajustes guardados en la memoria del teléfono', 'success');
  }

  // --- ITEMS LIST RENDERER IN POS ---
  function renderItemsList() {
    itemsListContainer.innerHTML = '';

    if (!state.items || state.items.length === 0) {
      itemsListContainer.innerHTML = `
        <div class="text-center py-6 text-on-surface-variant font-body-sm">
          <span class="material-symbols-outlined text-[32px] text-outline opacity-60 block mx-auto mb-1">shopping_cart</span>
          El ticket está vacío. Toca un producto de Venta Rápida.
        </div>
      `;
      return;
    }

    state.items.forEach(item => {
      const card = document.createElement('div');
      card.className = 'flex items-center justify-between p-2.5 rounded-xl bg-surface-container-low border border-surface-container';
      const rowTotal = ((parseFloat(item.cant) || 0) * (parseFloat(item.unitPrice) || 0)).toFixed(2);
      
      card.innerHTML = `
        <div class="flex flex-col min-w-0 pr-2 flex-1">
          <input type="text" class="font-label-md text-label-md text-on-surface font-semibold bg-transparent border-0 outline-none truncate w-full" value="${escapeHtml(item.desc || '')}" data-id="${item.id}" data-field="desc" placeholder="Descripción del producto..."/>
          <span class="font-body-sm text-body-sm text-on-surface-variant">$${parseFloat(item.unitPrice || 0).toFixed(2)} c/u</span>
        </div>
        <div class="flex items-center gap-2 shrink-0">
          <div class="flex items-center bg-surface-container-lowest rounded-lg shadow-sm border border-surface-container">
            <button class="btn-step-down w-7 h-7 flex items-center justify-center text-on-surface-variant hover:text-error active:scale-95 transition-all" data-id="${item.id}" type="button" title="${item.cant <= 1 ? 'Eliminar' : 'Disminuir'}">
              <span class="material-symbols-outlined text-[16px]">${item.cant <= 1 ? 'delete' : 'remove'}</span>
            </button>
            <span class="w-6 text-center font-label-numeric text-label-numeric text-on-surface font-bold">${item.cant}</span>
            <button class="btn-step-up w-7 h-7 flex items-center justify-center text-on-surface-variant hover:text-secondary active:scale-95 transition-all" data-id="${item.id}" type="button" title="Aumentar">
              <span class="material-symbols-outlined text-[16px]">add</span>
            </button>
          </div>
          <span class="font-label-numeric text-label-numeric text-on-surface font-bold text-right min-w-[65px]">$${rowTotal}</span>
        </div>
      `;

      itemsListContainer.appendChild(card);
    });

    itemsListContainer.querySelectorAll('input').forEach(input => {
      input.addEventListener('input', e => {
        const id = e.target.getAttribute('data-id');
        const field = e.target.getAttribute('data-field');
        const item = state.items.find(i => i.id === id);
        if (item) {
          item[field] = cleanInputText(e.target.value);
          updateCalculationsAndPreview();
        }
      });
    });

    itemsListContainer.querySelectorAll('.btn-step-down').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        const idx = state.items.findIndex(i => i.id === id);
        if (idx !== -1) {
          if (state.items[idx].cant > 1) {
            state.items[idx].cant -= 1;
          } else {
            state.items.splice(idx, 1);
          }
          renderItemsList();
          updateCalculationsAndPreview();
        }
      });
    });

    itemsListContainer.querySelectorAll('.btn-step-up').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        const item = state.items.find(i => i.id === id);
        if (item) {
          item.cant = (parseFloat(item.cant) || 0) + 1;
          renderItemsList();
          updateCalculationsAndPreview();
        }
      });
    });
  }

  // --- CALCULATIONS & PREVIEW BINDING ---
  function updateCalculationsAndPreview() {
    applyActiveRateMode();

    const c = state.business.currency || '$';
    const rate = state.exchange.rate > 0 ? state.exchange.rate : 1;

    const fmtBs = num => `Bs. ${num.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    const fmtInputCurr = num => `${c} ${num.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

    const tabBtnOpciones = document.getElementById('tab-btn-opciones');
    const btnNextStep2 = document.getElementById('btn-next-step-2');

    if (!state.options.showQR) {
      if (tabBtnOpciones) tabBtnOpciones.classList.add('hidden');
      if (btnNextStep2) {
        btnNextStep2.innerHTML = `<span>Guardar Comprobante</span> <i class="fa-solid fa-floppy-disk"></i>`;
      }
      const activeTabOpciones = document.getElementById('tab-opciones');
      if (activeTabOpciones && !activeTabOpciones.classList.contains('hidden') && switchSubtabByStepRef) {
        switchSubtabByStepRef(2);
      }
    } else {
      if (tabBtnOpciones) tabBtnOpciones.classList.remove('hidden');
      if (btnNextStep2) {
        btnNextStep2.innerHTML = `<span>Siguiente: QR & Extras</span> <i class="fa-solid fa-arrow-right"></i>`;
      }
    }

    viewBizName.textContent = state.business.name || 'NOMBRE DE TU NEGOCIO';
    viewBizId.textContent = state.business.id || '';
    viewBizAddress.textContent = state.business.address || '';
    viewBizPhone.textContent = state.business.phone || '';

    const sizePx = state.options.logoSize || 220;
    ticketLogoImg.style.maxWidth = `${sizePx}px`;
    ticketLogoImg.style.maxHeight = `${Math.round(sizePx * 0.65)}px`;

    viewDocTitle.textContent = state.business.docTitle || 'RECIBO';
    viewDocNumber.textContent = state.business.docNumber || formatFolioNumber(state.folioCounter);

    viewDocDate.textContent = state.client.date || '';
    viewDocTime.textContent = state.client.time || '';
    viewClientName.textContent = state.client.name || 'Cliente Mostrador';

    if (state.client.id) {
      document.getElementById('view-client-id-row').classList.remove('hidden');
      viewClientId.textContent = state.client.id;
    } else {
      document.getElementById('view-client-id-row').classList.add('hidden');
    }

    if (state.client.city) {
      document.getElementById('view-client-city-row').classList.remove('hidden');
      viewClientCity.textContent = state.client.city;
    } else {
      document.getElementById('view-client-city-row').classList.add('hidden');
    }

    viewPaymentForm.textContent = state.client.paymentForm || 'Pago Móvil';
    viewSalesperson.textContent = state.client.salesperson || 'Caja';

    let grandTotalMain = 0;

    if (state.docType === 'venta') {
      viewDocBadge.textContent = 'VENTA POS';
      viewLblPerson.textContent = 'Cliente:';
      viewLblSalesperson.textContent = 'Vendedor:';
      viewSignatureText.textContent = 'Firma Cliente / Recibido Conforme';

      ticketItemsBlock.classList.remove('hidden');
      ticketPaymentReceiptBlock.classList.add('hidden');
      viewSubtotalRow.classList.remove('hidden');
      viewItemsCountRow.classList.remove('hidden');
      viewTotalLbl.textContent = 'Total ($ USD):';

      let rawSubtotal = 0;
      state.items.forEach(item => {
        rawSubtotal += (item.cant * item.unitPrice);
      });

      const discount = state.totals.discount || 0;
      const taxableBase = Math.max(0, rawSubtotal - discount);
      const taxRate = state.totals.taxRate || 0;
      const taxAmount = (taxableBase * taxRate) / 100;
      grandTotalMain = taxableBase + taxAmount;

      state.totals.subtotal = rawSubtotal;
      state.totals.taxAmount = taxAmount;
      state.totals.grandTotal = grandTotalMain;

      viewItemsBody.innerHTML = '';
      state.items.forEach(item => {
        const itemTotal = item.cant * item.unitPrice;
        const row = document.createElement('div');
        row.className = 'ticket-item-row-group';
        row.innerHTML = `
          <div class="ticket-item-row">
            <span class="col-cant">${item.cant}</span>
            <span class="col-desc">${escapeHtml(item.desc || 'Producto / Servicio')}</span>
            <span class="col-total">${fmtInputCurr(itemTotal)}</span>
          </div>
          ${item.subtext ? `<div class="item-subtext">${escapeHtml(item.subtext)}</div>` : ''}
        `;
        viewItemsBody.appendChild(row);
      });

      viewSubtotal.textContent = fmtInputCurr(rawSubtotal);
      if (discount > 0) {
        viewDiscountRow.classList.remove('hidden');
        viewDiscount.textContent = `-${fmtInputCurr(discount)}`;
      } else {
        viewDiscountRow.classList.add('hidden');
      }

      if (taxAmount > 0) {
        viewTaxRow.classList.remove('hidden');
        viewTax.textContent = fmtInputCurr(taxAmount);
      } else {
        viewTaxRow.classList.add('hidden');
      }

      viewTotal.textContent = `${fmtInputCurr(grandTotalMain)} USD`;
      viewItemsCount.textContent = state.items.length;

      if (state.options.showTaxTable && taxAmount > 0) {
        viewTaxTableWrapper.classList.remove('hidden');
        viewTaxRateLbl.textContent = `IVA ${taxRate}%`;
        viewTaxBase.textContent = fmtInputCurr(taxableBase);
        viewTaxVal.textContent = fmtInputCurr(taxAmount);
      } else {
        viewTaxTableWrapper.classList.add('hidden');
      }

    } else {
      if (state.docType === 'ingreso') {
        viewDocBadge.textContent = 'RECIBO DE CAJA (INGRESO)';
        viewLblPerson.textContent = 'Recibido De:';
        viewLblSalesperson.textContent = 'Recibido Por:';
        viewTotalLbl.textContent = 'MONTO RECIBIDO:';
        viewSignatureText.textContent = 'Firma Quien Recibe / Conforme';
      } else {
        viewDocBadge.textContent = 'COMPROBANTE DE EGRESO';
        viewLblPerson.textContent = 'Pagado A:';
        viewLblSalesperson.textContent = 'Elaborado Por:';
        viewTotalLbl.textContent = 'MONTO PAGADO:';
        viewSignatureText.textContent = 'Firma Beneficiario / Recibí Conforme';
      }

      ticketItemsBlock.classList.add('hidden');
      ticketPaymentReceiptBlock.classList.remove('hidden');
      viewSubtotalRow.classList.add('hidden');
      viewDiscountRow.classList.add('hidden');
      viewTaxRow.classList.add('hidden');
      viewItemsCountRow.classList.add('hidden');
      viewTaxTableWrapper.classList.add('hidden');

      viewPaymentConcept.textContent = state.paymentDetails.concept || 'Pago por concepto de bienes/servicios.';
      
      if (state.paymentDetails.ref) {
        viewPaymentRefRow.classList.remove('hidden');
        viewPaymentRef.textContent = state.paymentDetails.ref;
      } else {
        viewPaymentRefRow.classList.add('hidden');
      }

      if (state.paymentDetails.prevBalance > 0) {
        viewPrevBalanceRow.classList.remove('hidden');
        viewPrevBalance.textContent = fmtInputCurr(state.paymentDetails.prevBalance);
      } else {
        viewPrevBalanceRow.classList.add('hidden');
      }

      if (state.paymentDetails.newBalance > 0) {
        viewNewBalanceRow.classList.remove('hidden');
        viewNewBalance.textContent = fmtInputCurr(state.paymentDetails.newBalance);
      } else {
        viewNewBalanceRow.classList.add('hidden');
      }

      grandTotalMain = state.paymentDetails.amount || 0;
      state.totals.grandTotal = grandTotalMain;
      viewTotal.textContent = `${fmtInputCurr(grandTotalMain)} USD`;
    }

    if (state.exchange.showDual) {
      viewDualCurrencyWrapper.classList.remove('hidden');
      const totalBs = grandTotalMain * rate;

      if (state.exchange.mode === 'bcv-eur') {
        viewDualTitle.textContent = `Equivalente en Bolívares (BCV €):`;
        viewUsdTotal.textContent = fmtBs(totalBs);
        viewExchangeRateLbl.textContent = `Tasa Ref BCV Euro (€): 1 EUR = ${rate.toFixed(2)} Bs.`;
      } else if (state.exchange.mode === 'custom') {
        viewDualTitle.textContent = `Equivalente en Bolívares:`;
        viewUsdTotal.textContent = fmtBs(totalBs);
        viewExchangeRateLbl.textContent = `Tasa Ref Personalizada: 1 USD = ${rate.toFixed(2)} Bs.`;
      } else {
        viewDualTitle.textContent = `Equivalente en Bolívares (BCV $):`;
        viewUsdTotal.textContent = fmtBs(totalBs);
        viewExchangeRateLbl.textContent = `Tasa Ref BCV Dólar ($): 1 USD = ${rate.toFixed(2)} Bs.`;
      }
    } else {
      viewDualCurrencyWrapper.classList.add('hidden');
    }

    if (state.options.showSignature) viewSignatureWrapper.classList.remove('hidden');
    else viewSignatureWrapper.classList.add('hidden');

    if (state.options.showBarcode) {
      barcodeWrapper.classList.remove('hidden');
      drawBarcodeCanvas(state.business.docNumber || 'FES-001');
    } else {
      barcodeWrapper.classList.add('hidden');
    }

    if (state.options.showQR) {
      viewQrWrapper.classList.remove('hidden');
      renderSuiche7bQRCode(grandTotalMain);
    } else {
      viewQrWrapper.classList.add('hidden');
    }

    if (state.options.notes && state.options.notes.trim() !== '') {
      if (viewNotesWrapper) viewNotesWrapper.classList.remove('hidden');
      if (viewNotesText) viewNotesText.textContent = state.options.notes;
    } else {
      if (viewNotesWrapper) viewNotesWrapper.classList.add('hidden');
    }

    // Update POS Header and Floating Active Client Info
    const activeClientName = document.getElementById('pos-active-client-name');
    if (activeClientName) activeClientName.textContent = state.client.name || 'Cliente Mostrador';
    const activeClientPhone = document.getElementById('pos-active-client-phone');
    if (activeClientPhone) activeClientPhone.textContent = state.client.phone || state.client.id || 'Mostrador General';

    const chargeBtnText = document.getElementById('stitch-charge-btn-text');
    if (chargeBtnText) chargeBtnText.textContent = `Cobrar $${grandTotalMain.toFixed(2)}`;
  }

  // --- SUICHE 7B QR GENERATOR ---
  function renderSuiche7bQRCode(amountMain) {
    const qrContainer = document.getElementById('qrcode');
    if (!qrContainer) return;
    qrContainer.innerHTML = '';

    const cleanBank = state.suiche.bank || '0134';
    const docType = state.suiche.docType || 'J';
    const cleanDocNum = (state.suiche.docNumber || '').replace(/[^0-9]/g, '');
    const fullDoc = `${docType}${cleanDocNum}`;
    const cleanPhone = (state.suiche.phone || '').replace(/[^0-9]/g, '');

    const rawConcept = (state.business.docNumber || 'FACTURA').replace(/[^a-zA-Z0-9]/g, '');

    let amountStr = '';
    if (state.suiche.amountMode === 'dynamic') {
      const finalBs = amountMain * (state.exchange.rate || 1);
      amountStr = finalBs.toFixed(2);
    }

    let suichePayload = `pagomovil:v=1;banco=${cleanBank};cedula=${fullDoc};telefono=${cleanPhone}`;
    if (amountStr && parseFloat(amountStr) > 0) suichePayload += `;monto=${amountStr}`;
    if (rawConcept) suichePayload += `;concepto=${rawConcept}`;

    if (suichePayloadText) suichePayloadText.textContent = suichePayload;
    if (viewQrCaption) viewQrCaption.textContent = cleanPhone ? `Escanea Pago Móvil Suiche 7B (${cleanBank} - ${fullDoc})` : `Escanea Pago Móvil Suiche 7B`;

    if (typeof QRCode !== 'undefined') {
      try {
        new QRCode(qrContainer, {
          text: suichePayload,
          width: 95,
          height: 95,
          colorDark: '#000000',
          colorLight: '#ffffff',
          correctLevel: QRCode.CorrectLevel.M
        });
      } catch (err) {}
    }
  }

  // --- BARCODE CANVAS GENERATOR ---
  function drawBarcodeCanvas(text) {
    const canvas = document.getElementById('barcode-canvas');
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    canvas.width = 240;
    canvas.height = 36;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.fillStyle = '#000000';

    let x = 10;
    const barWidths = [1, 2, 3, 1, 4, 2, 1, 3, 2, 1, 4, 1, 2];
    let strIndex = 0;

    ctx.fillRect(x, 2, 2, 28); x += 4;
    ctx.fillRect(x, 2, 1, 28); x += 3;

    while (x < canvas.width - 20) {
      const charCode = text.charCodeAt(strIndex % text.length) || 48;
      const w1 = barWidths[charCode % barWidths.length];
      const w2 = barWidths[(charCode + 3) % barWidths.length];

      ctx.fillRect(x, 2, w1, 28);
      x += w1 + w2;
      strIndex++;
    }

    ctx.fillRect(canvas.width - 15, 2, 2, 28);
    ctx.fillRect(canvas.width - 10, 2, 1, 28);

    ctx.font = '9px monospace';
    ctx.textAlign = 'center';
    ctx.fillText(text, canvas.width / 2, 35);
  }

  // --- COMPRESOR DE IMÁGENES CLIENT-SIDE (Previene errores de memoria en localStorage) ---
  function compressImageFile(file, maxWidth, maxHeight, quality, callback) {
    if (!file) return;
    const isPng = file.type === 'image/png';
    const outputFormat = isPng ? 'image/png' : 'image/jpeg';
    const reader = new FileReader();
    reader.onload = function (evt) {
      const img = new Image();
      img.onload = function () {
        let w = img.width;
        let h = img.height;
        if (w > maxWidth || h > maxHeight) {
          if (w > h) {
            h = Math.round((h * maxWidth) / w);
            w = maxWidth;
          } else {
            w = Math.round((w * maxHeight) / h);
            h = maxHeight;
          }
        }
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        ctx.drawImage(img, 0, 0, w, h);
        const compressedDataUrl = canvas.toDataURL(outputFormat, quality || 0.85);
        callback(compressedDataUrl);
      };
      img.onerror = function () {
        // Fallback: direct data URL
        callback(evt.target.result);
      };
      img.src = evt.target.result;
    };
    reader.onerror = function () {
      showToast('Error al leer el archivo de imagen.', 'info');
    };
    reader.readAsDataURL(file);
  }

  // --- LOGO UPLOAD & REMOVE ---
  function handleLogoUpload(e) {
    const file = e.target.files ? e.target.files[0] : null;
    if (!file) return;

    showToast('Procesando logo de la empresa...', 'info');

    compressImageFile(file, 600, 600, 0.85, function(dataUrl) {
      applyLogoToStateAndUI(dataUrl);
      showToast('Logo de la empresa guardado exitosamente.', 'success');
    });
  }

  function applyLogoToStateAndUI(dataUrl) {
    state.business.logo = dataUrl;
    logoPreview.innerHTML = `<img src="${dataUrl}" alt="Logo Preview" style="max-height:100px;">`;
    ticketLogoImg.src = dataUrl;
    ticketLogoImg.classList.remove('hidden');
    btnRemoveLogo.classList.remove('hidden');
    autoSaveSettings();
  }

  function handleLogoRemove() {
    state.business.logo = null;
    inputLogo.value = '';
    logoPreview.innerHTML = `<i class="fa-solid fa-cloud-arrow-up"></i><span>Subir Logo</span>`;
    ticketLogoImg.src = '';
    ticketLogoImg.classList.add('hidden');
    btnRemoveLogo.classList.add('hidden');
    autoSaveSettings();
  }

  // --- PRODUCT CATALOG MANAGEMENT ---
  function loadProductsFromStorage() {
    try {
      const saved = localStorage.getItem('martk_products');
      state.productsCatalog = saved ? JSON.parse(saved) : [];
      renderProductsTable();
      renderPosQuickCatalog();
    } catch(err) {
      state.productsCatalog = [];
      renderProductsTable();
      renderPosQuickCatalog();
    }
  }

  
  // --- DYNAMIC POS QUICK CATALOG RENDERER ---
  function renderPosQuickCatalog() {
    const grid = document.getElementById('pos-quick-catalog-grid');
    if (!grid) return;
    grid.innerHTML = '';

    if (!state.productsCatalog || state.productsCatalog.length === 0) {
      grid.innerHTML = `
        <div class="col-span-2 text-center py-10 px-4 bg-surface-container-lowest rounded-xl border border-dashed border-surface-container space-y-2">
          <span class="material-symbols-outlined text-[36px] text-outline opacity-60">inventory_2</span>
          <p class="font-label-md text-label-md font-bold text-on-surface">Tu catálogo está en 0</p>
          <p class="font-body-sm text-body-sm text-on-surface-variant">Agrega productos en "Productos" o usa "+ Partida Manual" arriba.</p>
        </div>
      `;
      return;
    }

    const searchInput = document.getElementById('stitch-pos-search');
    const query = (searchInput ? searchInput.value : '').toLowerCase().trim();
    const activeCatBtn = document.querySelector('.pos-cat-btn.bg-primary');
    const activeCat = activeCatBtn ? activeCatBtn.getAttribute('data-cat') : 'all';

    const rate = state.exchange.rate > 0 ? state.exchange.rate : 1;

    const filtered = state.productsCatalog.filter(p => {
      const matchText = (p.nombre || '').toLowerCase().includes(query) || (p.subtexto || '').toLowerCase().includes(query) || (p.codigo || '').toLowerCase().includes(query);
      if (!matchText) return false;
      if (activeCat && activeCat !== 'all') {
        const catText = ((p.categoria || '') + ' ' + (p.nombre || '')).toLowerCase();
        return catText.includes(activeCat.toLowerCase());
      }
      return true;
    });

    if (filtered.length === 0) {
      grid.innerHTML = `
        <div class="col-span-2 text-center py-8 text-on-surface-variant font-label-sm">
          No hay productos que coincidan con la búsqueda.
        </div>
      `;
      return;
    }

    filtered.forEach(p => {
      const priceUsd = parseFloat(p.precio_usd || 0);
      const priceBs = priceUsd * rate;
      const card = document.createElement('div');
      card.className = 'pos-product-card bg-surface-container-lowest rounded-xl p-3 shadow-sm border border-surface-container flex flex-col justify-between hover:border-secondary transition-all cursor-pointer group';
      card.innerHTML = `
        <div>
          <span class="px-2 py-0.5 rounded bg-surface-container font-label-sm text-label-sm font-semibold text-secondary">${escapeHtml(p.codigo || 'PRD')}</span>
          <p class="font-label-md text-label-md text-on-surface font-bold mt-1 line-clamp-1 group-hover:text-secondary transition-colors">${escapeHtml(p.nombre || 'Producto')}</p>
          <p class="font-body-sm text-body-sm text-on-surface-variant line-clamp-1">${escapeHtml(p.subtexto || '')}</p>
        </div>
        <div class="flex items-center justify-between pt-2 mt-2 border-t border-surface-container">
          <div class="flex flex-col">
            <span class="font-headline-sm text-headline-sm text-on-surface font-bold font-mono">$${priceUsd.toFixed(2)}</span>
            <span class="text-[10px] text-on-surface-variant font-mono">Bs. ${priceBs.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}</span>
          </div>
          <button class="w-8 h-8 rounded-lg bg-surface-container text-secondary flex items-center justify-center group-hover:bg-secondary group-hover:text-on-secondary transition-colors" type="button" title="Añadir al ticket">
            <span class="material-symbols-outlined text-[18px]">add</span>
          </button>
        </div>
      `;

      card.addEventListener('click', () => {
        addCatalogProductToTicket(p);
      });

      grid.appendChild(card);
    });
  }

  function addCatalogProductToTicket(p) {
    const desc = p.nombre || 'Producto';
    const sub = p.subtexto || '';
    const price = parseFloat(p.precio_usd) || 0;
    const tax = parseFloat(p.iva_porcentaje) || 0;

    const existing = state.items.find(i => i.desc === desc);
    if (existing) {
      existing.cant = (parseFloat(existing.cant) || 0) + 1;
    } else {
      state.items.push({
        id: Date.now().toString(),
        cant: 1,
        desc: desc,
        subtext: sub,
        taxRate: tax,
        unitPrice: price
      });
    }
    renderItemsList();
    updateCalculationsAndPreview();
    showToast(`Añadido al ticket: ${desc}`, 'success');
  }

  function renderProductsTable() {
    if (!productsTableBody) return;
    const query = (searchProducts ? searchProducts.value : '').toLowerCase().trim();
    productsTableBody.innerHTML = '';

    const filtered = state.productsCatalog.filter(p => {
      if (!query) return true;
      return (p.nombre || '').toLowerCase().includes(query) || (p.codigo || '').toLowerCase().includes(query);
    });

    if (filtered.length === 0) {
      productsTableBody.innerHTML = `<tr><td colspan="6" style="text-align:center; padding:1.5rem; color:#94A3B8;">No se encontraron productos registrados.</td></tr>`;
      return;
    }

    filtered.forEach(p => {
      const tr = document.createElement('tr');
      const costo = parseFloat(p.costo_usd || 0);
      const precio = parseFloat(p.precio_usd || 0);
      const ganancia = precio - costo;
      const margenPct = precio > 0 ? ((ganancia / precio) * 100).toFixed(0) : 0;
      const stock = parseFloat(p.stock_actual || 0);
      const stockMin = parseFloat(p.stock_min || 0);
      const isLowStock = stockMin > 0 && stock <= stockMin;

      tr.innerHTML = `
        <td><strong class="font-mono text-secondary">${escapeHtml(p.codigo || '-')}</strong></td>
        <td>
          <div class="font-bold text-on-surface">${escapeHtml(p.nombre)}</div>
          <small class="text-on-surface-variant">${escapeHtml(p.subtexto || p.unidad || '-')}</small>
        </td>
        <td class="font-mono font-semibold">$${costo.toFixed(2)}</td>
        <td><strong class="font-mono text-secondary">$${precio.toFixed(2)}</strong></td>
        <td>
          <span class="px-2 py-0.5 rounded text-[11px] font-bold ${ganancia >= 0 ? 'bg-secondary/10 text-secondary' : 'bg-error/10 text-error'} font-mono">
            +$${ganancia.toFixed(2)} (${margenPct}%)
          </span>
        </td>
        <td>
          <span class="px-2 py-0.5 rounded font-mono text-xs font-bold ${isLowStock ? 'bg-error/15 text-error animate-pulse' : 'bg-surface-container text-on-surface'}">
            ${stock} ${escapeHtml(p.unidad || '')}
          </span>
        </td>
        <td style="text-align:right;">
          <button class="px-2.5 py-1 rounded-lg bg-surface-container text-secondary hover:bg-surface-container-high transition-colors font-label-sm text-xs font-bold btn-add-prod-to-pos" data-id="${p.id}" title="Usar en POS">
            <span class="material-symbols-outlined text-[15px] align-middle">add_shopping_cart</span>
          </button>
          <button class="px-2 py-1 rounded-lg bg-error/10 text-error hover:bg-error hover:text-on-error transition-colors text-xs font-bold btn-del-prod ml-1" data-id="${p.id}" title="Eliminar">
            <span class="material-symbols-outlined text-[15px] align-middle">delete</span>
          </button>
        </td>
      `;
      productsTableBody.appendChild(tr);
    });

    productsTableBody.querySelectorAll('.btn-add-prod-to-pos').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        const prod = state.productsCatalog.find(p => String(p.id) === String(id));
        if (prod) addProductToPosReceipt(prod);
      });
    });

    productsTableBody.querySelectorAll('.btn-del-prod').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        state.productsCatalog = state.productsCatalog.filter(p => String(p.id) !== String(id));
        if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_products', state.productsCatalog); } else { localStorage.setItem('martk_products', JSON.stringify(state.productsCatalog)); }
        renderProductsTable();
        showToast('Producto eliminado.', 'info');
      });
    });
  }

  function handleSaveProduct(e) {
    e.preventDefault();
    const idVal = document.getElementById('prod-id').value;
    const codigo = cleanInputText(document.getElementById('prod-code').value).toUpperCase() || `PRD-${Date.now().toString().slice(-4)}`;
    const nombre = cleanInputText(document.getElementById('prod-name').value);
    const costo_usd = parseFloat(document.getElementById('prod-cost') ? document.getElementById('prod-cost').value : 0) || 0;
    const precio_usd = parseFloat(document.getElementById('prod-price').value) || 0;
    const stock_actual = parseFloat(document.getElementById('prod-stock') ? document.getElementById('prod-stock').value : 0) || 0;
    const stock_min = parseFloat(document.getElementById('prod-stock-min') ? document.getElementById('prod-stock-min').value : 0) || 0;
    const unidad = document.getElementById('prod-unit') ? document.getElementById('prod-unit').value : 'Unidad';
    const iva_porcentaje = parseFloat(document.getElementById('prod-tax').value) || 0;
    const subtexto = cleanInputText(document.getElementById('prod-subtext').value);

    const prodObj = {
      id: idVal ? parseInt(idVal) : undefined,
      codigo,
      nombre,
      costo_usd,
      precio_usd,
      stock_actual,
      stock_min,
      unidad,
      iva_porcentaje,
      subtexto
    };

    if (idVal) {
      const idx = state.productsCatalog.findIndex(p => String(p.id) === String(idVal));
      if (idx !== -1) state.productsCatalog[idx] = { ...state.productsCatalog[idx], ...prodObj };
    } else {
      state.productsCatalog.unshift({ id: Date.now(), ...prodObj });
    }

    if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_products', state.productsCatalog); } else { localStorage.setItem('martk_products', JSON.stringify(state.productsCatalog)); }
    renderProductsTable();
    renderPosQuickCatalog();
    if (productFormBox) productFormBox.classList.add('hidden');
    formProduct.reset();
    const marginDisp = document.getElementById('prod-margin-display');
    if (marginDisp) marginDisp.textContent = 'Ganancia: $0.00 (0%)';
    showToast('Producto y costo guardados correctamente', 'success');
  }

  function openProductPickerModal() {
    renderProductPickerGrid();
    modalProductPicker.classList.remove('hidden');
  }

  function renderProductPickerGrid() {
    const query = (pickerSearchProduct ? pickerSearchProduct.value : '').toLowerCase().trim();
    pickerProductList.innerHTML = '';

    const filtered = state.productsCatalog.filter(p => {
      if (!query) return true;
      return (p.nombre || '').toLowerCase().includes(query) || (p.codigo || '').toLowerCase().includes(query);
    });

    if (filtered.length === 0) {
      pickerProductList.innerHTML = `<div style="grid-column:1/-1; text-align:center; padding:1.5rem; color:#94A3B8;">No hay productos registrados. Crea uno en la sección Productos.</div>`;
      return;
    }

    filtered.forEach(p => {
      const card = document.createElement('div');
      card.className = 'picker-card';
      card.innerHTML = `
        <span class="picker-card-title">${escapeHtml(p.nombre)}</span>
        <span class="picker-card-price">$${parseFloat(p.precio_usd).toFixed(2)} USD</span>
        <small style="color:#64748B;">${p.subtexto ? escapeHtml(p.subtexto) : 'Sin detalles'}</small>
      `;
      card.addEventListener('click', () => {
        addProductToPosReceipt(p);
        modalProductPicker.classList.add('hidden');
      });
      pickerProductList.appendChild(card);
    });
  }

  function addProductToPosReceipt(product) {
    if (state.items.length === 1 && state.items[0].desc === '' && state.items[0].unitPrice === 0) {
      state.items = [];
    }

    state.items.push({
      id: Date.now().toString(),
      cant: 1,
      desc: product.nombre,
      subtext: product.subtexto || '',
      taxRate: product.iva_porcentaje || 0,
      unitPrice: product.precio_usd || 0
    });

    renderItemsList();
    updateCalculationsAndPreview();
    showToast(`Agregado a la factura: ${product.nombre}`, 'success');
  }

  // --- CLIENT CATALOG MANAGEMENT ---
  function loadClientsFromStorage() {
    try {
      const saved = localStorage.getItem('martk_clients');
      if (saved) {
        state.clientsCatalog = JSON.parse(saved);
      } else {
        state.clientsCatalog = [];
      }
      renderClientsTable();
    } catch(err) {
      state.clientsCatalog = [];
      renderClientsTable();
    }
  }

  function renderClientsTable() {
    if (!clientsTableBody) return;
    const query = (searchClients ? searchClients.value : '').toLowerCase().trim();
    clientsTableBody.innerHTML = '';

    const filtered = state.clientsCatalog.filter(c => {
      if (!query) return true;
      return (c.nombre || '').toLowerCase().includes(query) || (c.identificacion || '').toLowerCase().includes(query);
    });

    if (filtered.length === 0) {
      clientsTableBody.innerHTML = `<tr><td colspan="5" style="text-align:center; padding:1.5rem; color:#94A3B8;">No hay clientes en el directorio. Regístralos o se guardarán solos al facturar.</td></tr>`;
      return;
    }

    filtered.forEach(c => {
      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td><strong>${escapeHtml(c.identificacion)}</strong></td>
        <td>${escapeHtml(c.nombre)}</td>
        <td>${escapeHtml(c.telefono || '-')}</td>
        <td><small>${escapeHtml(c.direccion || '-')}</small></td>
        <td>
          <button class="btn btn-sm btn-primary btn-select-client-pos" data-id="${c.id}"><i class="fa-solid fa-user-check"></i> Facturar A</button>
          <button class="btn btn-sm btn-danger-outline btn-del-client" data-id="${c.id}"><i class="fa-solid fa-trash"></i></button>
        </td>
      `;
      clientsTableBody.appendChild(tr);
    });

    clientsTableBody.querySelectorAll('.btn-select-client-pos').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        const client = state.clientsCatalog.find(c => String(c.id) === String(id));
        if (client) selectClientForPosReceipt(client);
      });
    });

    clientsTableBody.querySelectorAll('.btn-del-client').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        state.clientsCatalog = state.clientsCatalog.filter(c => String(c.id) !== String(id));
        if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_clients', state.clientsCatalog); } else { localStorage.setItem('martk_clients', JSON.stringify(state.clientsCatalog)); }
        renderClientsTable();
        showToast('Cliente eliminado del directorio.', 'info');
      });
    });
  }

  function handleSaveClient(e) {
    e.preventDefault();
    const identificacion = cleanIdentificacionInput(document.getElementById('c-doc').value);
    const nombre = cleanInputText(document.getElementById('c-name').value);
    const telefono = cleanPhoneInput(document.getElementById('c-phone').value);
    const direccion = cleanInputText(document.getElementById('c-address').value);

    const cleanNum = identificacion.replace(/[^0-9]/g, '');
    const existing = state.clientsCatalog.find(c => (c.identificacion || '').replace(/[^0-9]/g, '') === cleanNum);

    if (existing) {
      showToast(`El cliente con Cédula/RIF ${identificacion} ya se encuentra registrado (${existing.nombre}).`, 'info');
      return;
    }

    const clientObj = { id: Date.now(), identificacion, nombre, telefono, direccion };
    state.clientsCatalog.unshift(clientObj);

    if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_clients', state.clientsCatalog); } else { localStorage.setItem('martk_clients', JSON.stringify(state.clientsCatalog)); }
    renderClientsTable();
    clientFormBox.classList.add('hidden');
    formClient.reset();
    showToast('Cliente registrado correctamente', 'success');
  }

  function openClientPickerModal() {
    renderClientPickerList();
    modalClientPicker.classList.remove('hidden');
  }

  function renderClientPickerList() {
    const query = (pickerSearchClient ? pickerSearchClient.value : '').toLowerCase().trim();
    pickerClientList.innerHTML = '';

    const filtered = state.clientsCatalog.filter(c => {
      if (!query) return true;
      return (c.nombre || '').toLowerCase().includes(query) || (c.identificacion || '').toLowerCase().includes(query);
    });

    if (filtered.length === 0) {
      pickerClientList.innerHTML = `<div style="text-align:center; padding:1.5rem; color:#94A3B8;">No hay clientes registrados. Regístralo en la sección Clientes.</div>`;
      return;
    }

    filtered.forEach(c => {
      const row = document.createElement('div');
      row.className = 'picker-item-row';
      row.innerHTML = `
        <div>
          <strong style="color:#0F172A;">${escapeHtml(c.nombre)}</strong>
          <div style="font-size:0.75rem; color:#64748B;">Doc: ${escapeHtml(c.identificacion)} ${c.telefono ? '• Tel: ' + escapeHtml(c.telefono) : ''}</div>
        </div>
        <button class="btn btn-sm btn-primary"><i class="fa-solid fa-check"></i> Seleccionar</button>
      `;
      row.addEventListener('click', () => {
        selectClientForPosReceipt(c);
        modalClientPicker.classList.add('hidden');
      });
      pickerClientList.appendChild(row);
    });
  }

  function selectClientForPosReceipt(client) {
    state.client.name = client.nombre;
    inputClientName.value = client.nombre;

    state.client.id = client.identificacion;
    inputClientId.value = client.identificacion;

    if (client.telefono) {
      state.client.phone = client.telefono;
      inputClientPhone.value = client.telefono;
    }

    if (client.direccion) {
      state.client.city = client.direccion;
      inputClientCity.value = client.direccion;
    }

    updateCalculationsAndPreview();
    showToast(`Cliente seleccionado: ${client.nombre}`, 'success');
  }

  // --- SETTINGS PERSISTENCE & LOAD ---
  function applySettingsObject(settingsObj) {
    if (!settingsObj) return;

    if (settingsObj.business) {
      state.business = { ...state.business, ...settingsObj.business };
      if (inputBizName) inputBizName.value = state.business.name || '';
      if (inputBizId) inputBizId.value = state.business.id || '';
      if (inputBizPhone) inputBizPhone.value = state.business.phone || '';
      if (inputBizAddress) inputBizAddress.value = state.business.address || '';
      const selectBizCat = document.getElementById('biz-category');
      if (selectBizCat && state.business.category) selectBizCat.value = state.business.category;
    }

    if (settingsObj.exchange) {
      if (settingsObj.exchange.bcvUsd && settingsObj.exchange.bcvUsd < 850) {
        settingsObj.exchange.bcvUsd = 881.88;
      }
      if (settingsObj.exchange.rate && settingsObj.exchange.rate < 850 && settingsObj.exchange.mode === 'bcv-usd') {
        settingsObj.exchange.rate = 881.88;
      }
      if (settingsObj.exchange.bcvEur && settingsObj.exchange.bcvEur < 900) {
        settingsObj.exchange.bcvEur = 988.97;
      }
      state.exchange = { ...state.exchange, ...settingsObj.exchange };
      updateRateOptionsDropdown();
      applyActiveRateMode();
    }

    if (settingsObj.suiche) {
      state.suiche = { ...state.suiche, ...settingsObj.suiche };
      if (selectSuicheBank) selectSuicheBank.value = state.suiche.bank || '0134';
      if (selectSuicheDocType) selectSuicheDocType.value = state.suiche.docType || 'J';
      if (inputSuicheDocNumber) inputSuicheDocNumber.value = state.suiche.docNumber || '';
      if (inputSuichePhone) inputSuichePhone.value = state.suiche.phone || '';
      if (selectSuicheAmountMode) selectSuicheAmountMode.value = state.suiche.amountMode || 'dynamic';
    }

    if (settingsObj.options) {
      state.options = { ...state.options, ...settingsObj.options };
      if (inputFooterNotes) inputFooterNotes.value = state.options.notes || '';
      if (logoSizeRange) {
        logoSizeRange.value = state.options.logoSize || 220;
        if (logoSizeVal) logoSizeVal.textContent = `${state.options.logoSize || 220} px`;
      }

      if (prefShowQr) prefShowQr.checked = !!state.options.showQR;
      if (prefShowBarcode) prefShowBarcode.checked = !!state.options.showBarcode;
      if (prefShowSignature) prefShowSignature.checked = !!state.options.showSignature;
      if (prefShowTaxTable) prefShowTaxTable.checked = !!state.options.showTaxTable;

      if (state.options.theme) {
        themeCards.forEach(card => {
          if (card.getAttribute('data-theme') === state.options.theme) {
            themeCards.forEach(c => c.classList.remove('active'));
            card.classList.add('active');
            ticketCard.className = `ticket-card ${state.options.theme}`;
          }
        });
      }
    }

    if (state.business.logo) {
      if (logoPreview) logoPreview.innerHTML = `<img src="${state.business.logo}" alt="Logo" style="max-height:100px;">`;
      if (ticketLogoImg) {
        ticketLogoImg.src = state.business.logo;
        ticketLogoImg.classList.remove('hidden');
      }
      if (btnRemoveLogo) btnRemoveLogo.classList.remove('hidden');
    }
  }

  function loadSavedSettingsAndBusiness() {
    try {
      const savedLocal = localStorage.getItem('martk_settings_permanent');
      if (savedLocal) {
        applySettingsObject(JSON.parse(savedLocal));
      } else {
        state.business.name = '';
        state.business.id = '';
        state.business.phone = '';
        state.business.address = '';
        state.business.docTitle = 'FACTURA DE VENTA';
        state.business.currency = '$';
      }
      updateCalculationsAndPreview();
    } catch(err) {}
  }

  // --- SAVE RECEIPT TO HISTORY ---
  const saveCurrentDocumentToHistory = () => saveCurrentReceiptToHistory();

  function saveCurrentReceiptToHistory() {
    const rate = state.exchange.rate || 1;
    const totalBs = state.totals.grandTotal * rate;

    const receiptRecord = {
      uuid: Date.now().toString(),
      doc_type: state.docType,
      doc_title: state.business.docTitle,
      doc_number: state.business.docNumber,
      doc_date: state.client.date,
      doc_time: state.client.time,
      cliente_nombre: state.client.name || 'Cliente Mostrador',
      cliente_identificacion: state.client.id,
      cliente_telefono: state.client.phone,
      cliente_direccion: state.client.city,
      forma_pago: state.client.paymentForm,
      vendedor: state.client.salesperson,
      concepto: state.paymentDetails.concept,
      referencia: state.paymentDetails.ref,
      saldo_anterior: state.paymentDetails.prevBalance,
      nuevo_saldo: state.paymentDetails.newBalance,
      subtotal: state.totals.subtotal,
      impuesto_porcentaje: state.totals.taxRate,
      impuesto_monto: state.totals.taxAmount,
      descuento: state.totals.discount,
      total_principal: state.totals.grandTotal,
      total_bs_bcv: totalBs,
      moneda: state.business.currency,
      tasa_ref: state.exchange.rate,
      target_currency: state.exchange.mode === 'bcv-eur' ? 'EUR' : 'USD',
      suiche_bank: state.suiche.bank,
      suiche_doc: `${state.suiche.docType}${state.suiche.docNumber}`,
      suiche_phone: state.suiche.phone,
      items: JSON.parse(JSON.stringify(state.items))
    };

    state.history.unshift(receiptRecord);
    saveHistoryToStorage();

    // Integración Automática con Inventario: Descontar Stock
    if (receiptRecord.items && Array.isArray(receiptRecord.items)) {
      receiptRecord.items.forEach(it => {
        const p = state.productsCatalog.find(prod => (prod.code && prod.code === it.code) || (prod.name && prod.name.toLowerCase() === (it.name || '').toLowerCase()));
        if (p && typeof p.stock === 'number') {
          p.stock = Math.max(0, p.stock - (Number(it.qty) || 1));
        }
      });
      saveProductsToStorage();
    }

    // Integración Automática con Libro de Caja
    const isCredit = (receiptRecord.forma_pago || '').toLowerCase().includes('crédito') || (receiptRecord.forma_pago || '').toLowerCase().includes('credito');
    const prevBal = Number(receiptRecord.saldo_anterior) || 0;
    const newBal = Number(receiptRecord.nuevo_saldo) || 0;
    const initialPayment = isCredit ? Math.max(0, receiptRecord.total_principal - newBal) : receiptRecord.total_principal;

    if (initialPayment > 0) {
      const cashEntry = {
        id: 'caja_' + receiptRecord.uuid,
        date: new Date().toISOString(),
        type: 'income',
        category: isCredit ? 'Abono / Anticipo de Inicial' : 'Venta Directa POS',
        concept: `${receiptRecord.doc_title || 'Comprobante'} #${receiptRecord.doc_number || ''} - ${receiptRecord.cliente_nombre}`,
        amountUsd: initialPayment,
        amountBs: initialPayment * (state.exchange.rate || 1),
        method: mapPaymentFormToCajaMethod(receiptRecord.forma_pago),
        reference: receiptRecord.referencia || receiptRecord.doc_number || '',
        thirdParty: receiptRecord.cliente_nombre,
        relatedReceiptId: receiptRecord.uuid,
        salesperson: receiptRecord.vendedor || ''
      };
      state.cashMovements.unshift(cashEntry);
      saveCashMovementsToStorage();
    }

    // Integración Automática con Cuentas por Cobrar si es a crédito
    if (isCredit || newBal > 0) {
      const debtAmount = newBal > 0 ? newBal : Math.max(0, receiptRecord.total_principal - initialPayment);
      if (debtAmount > 0) {
        const cxcRecord = {
          id: 'cxc_' + receiptRecord.uuid,
          receiptId: receiptRecord.uuid,
          docNumber: receiptRecord.doc_number || 'N/A',
          clientName: receiptRecord.cliente_nombre || 'Cliente General',
          clientId: receiptRecord.cliente_identificacion || '',
          clientPhone: receiptRecord.cliente_telefono || '',
          date: receiptRecord.doc_date || new Date().toISOString().split('T')[0],
          dueDate: new Date(Date.now() + 15 * 86400000).toISOString().split('T')[0],
          totalDebtUsd: receiptRecord.total_principal,
          paidUsd: initialPayment,
          balanceUsd: debtAmount,
          concept: `${receiptRecord.doc_title || 'Venta a Crédito'} #${receiptRecord.doc_number || ''}`,
          status: debtAmount <= 0.01 ? 'paid' : 'pending',
          abonos: initialPayment > 0 ? [{
            date: new Date().toISOString(),
            amountUsd: initialPayment,
            method: receiptRecord.forma_pago,
            reference: 'Inicial'
          }] : []
        };
        state.cuentasPorCobrar.unshift(cxcRecord);
        saveCxcToStorage();
      }
    }

    // Auto-registrar cliente en el directorio si tiene cédula y nombre válido
    if (state.client.id && state.client.name && state.client.name !== 'Cliente Mostrador') {
      const cleanNum = state.client.id.replace(/[^0-9]/g, '');
      if (cleanNum) {
        const exists = state.clientsCatalog.some(c => (c.identificacion || '').replace(/[^0-9]/g, '') === cleanNum);
        if (!exists) {
          state.clientsCatalog.unshift({
            id: Date.now(),
            identificacion: state.client.id,
            nombre: state.client.name,
            telefono: state.client.phone || '',
            direccion: state.client.city || ''
          });
          if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_clients', state.clientsCatalog); } else { localStorage.setItem('martk_clients', JSON.stringify(state.clientsCatalog)); }
          renderClientsTable();
        }
      }
    }

    incrementFolioCounter();
    updateCalculationsAndPreview();

    showToast(`Comprobante guardado. Proximo folio: ${state.business.docNumber}`, 'success');
    switchView('view-ticket');
  }

  function incrementFolioCounter() {
    state.folioCounter++;
    state.business.docNumber = formatFolioNumber(state.folioCounter);
    if (posDocNumber) posDocNumber.textContent = state.business.docNumber;
    if (inputDocNumber) inputDocNumber.value = state.business.docNumber;
    if (inputFolioCounter) inputFolioCounter.value = state.folioCounter;
    if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_folio_counter', state.folioCounter.toString()); } else { localStorage.setItem('martk_folio_counter', state.folioCounter.toString()); }
  }

  function renderHistoryTable() {
    if (!historyTableBody) return;
    const query = (searchHistory ? searchHistory.value : '').toLowerCase().trim();
    historyTableBody.innerHTML = '';

    const filtered = state.history.filter(item => {
      if (!query) return true;
      return (item.cliente_nombre || '').toLowerCase().includes(query) ||
             (item.doc_number || '').toLowerCase().includes(query) ||
             (item.concepto || '').toLowerCase().includes(query);
    });

    if (filtered.length === 0) {
      historyTableBody.innerHTML = `<tr><td colspan="8" style="text-align:center; padding:1.5rem; color:#94A3B8;">No hay comprobantes guardados.</td></tr>`;
      return;
    }

    filtered.forEach(item => {
      const tr = document.createElement('tr');
      const typeLabel = item.doc_type === 'ingreso' ? 'Ingreso' : (item.doc_type === 'egreso' ? 'Egreso' : 'Factura Venta');

      tr.innerHTML = `
        <td><strong style="color:#4F46E5;">${escapeHtml(item.doc_number)}</strong></td>
        <td><span class="auto-save-indicator">${typeLabel}</span></td>
        <td><small>${escapeHtml(item.doc_date)} ${escapeHtml(item.doc_time || '')}</small></td>
        <td>${escapeHtml(item.cliente_nombre)}</td>
        <td><small>${escapeHtml(item.forma_pago || '-')}</small></td>
        <td><strong style="color:#059669;">$${parseFloat(item.total_principal).toFixed(2)} USD</strong></td>
        <td><small>Bs. ${parseFloat(item.total_bs_bcv || 0).toLocaleString('es-VE', { minimumFractionDigits: 2 })}</small></td>
        <td>
          <button class="btn btn-sm btn-primary btn-load-hist" data-uuid="${item.uuid}"><i class="fa-solid fa-folder-open"></i> Cargar</button>
          <button class="btn btn-sm btn-danger-outline btn-del-hist" data-uuid="${item.uuid}"><i class="fa-solid fa-trash"></i></button>
        </td>
      `;
      historyTableBody.appendChild(tr);
    });

    historyTableBody.querySelectorAll('.btn-load-hist').forEach(btn => {
      btn.addEventListener('click', () => {
        const uuid = btn.getAttribute('data-uuid');
        const target = state.history.find(h => h.uuid === uuid);
        if (target) {
          loadReceiptRecordToForm(target);
          state.activeView = 'view-pos';
          document.querySelector('.nav-item[data-view="view-pos"]').click();
          showToast('Comprobante cargado en el editor POS.', 'success');
        }
      });
    });

    historyTableBody.querySelectorAll('.btn-del-hist').forEach(btn => {
      btn.addEventListener('click', () => {
        const uuid = btn.getAttribute('data-uuid');
        state.history = state.history.filter(h => h.uuid !== uuid);
        saveHistoryToStorage();
        renderHistoryTable();
        showToast('Comprobante eliminado del historial.', 'info');
      });
    });
  }

  function loadReceiptRecordToForm(record) {
    state.docType = record.doc_type || 'venta';
    state.business.docTitle = record.doc_title;
    state.business.docNumber = record.doc_number;

    state.client.name = record.cliente_nombre;
    state.client.id = record.cliente_identificacion;
    state.client.phone = record.cliente_telefono;
    state.client.city = record.cliente_direccion;
    state.client.paymentForm = record.forma_pago || 'Pago Móvil';
    state.client.salesperson = record.vendedor;
    state.client.date = record.doc_date;
    state.client.time = record.doc_time;

    if (record.tasa_ref) {
      state.exchange.rate = record.tasa_ref;
      if (inputCustomRate) inputCustomRate.value = record.tasa_ref;
    }

    state.paymentDetails.concept = record.concepto || '';
    state.paymentDetails.amount = record.total_principal || 0;
    state.paymentDetails.ref = record.referencia || '';

    if (record.items && Array.isArray(record.items)) {
      state.items = JSON.parse(JSON.stringify(record.items));
    }

    setDocumentType(state.docType);
    inputClientName.value = state.client.name;
    inputClientId.value = state.client.id;
    inputClientPhone.value = state.client.phone;
    inputClientCity.value = state.client.city;

    selectPaymentForm.value = state.client.paymentForm;
    inputSalesperson.value = state.client.salesperson;
    inputDocDate.value = state.client.date;
    inputDocTime.value = state.client.time;

    inputPaymentConcept.value = state.paymentDetails.concept;
    inputPaymentAmount.value = state.paymentDetails.amount;
    inputPaymentRef.value = state.paymentDetails.ref;

    renderItemsList();
    updateCalculationsAndPreview();
  }

  function saveHistoryToStorage() {
    if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_history_records', state.history); } else { localStorage.setItem('martk_history_records', JSON.stringify(state.history)); }
    if (sidebarHistoryCount) sidebarHistoryCount.textContent = state.history.length;
  }

  function loadHistoryFromStorage() {
    try {
      const savedHist = localStorage.getItem('martk_history_records');
      if (savedHist) {
        state.history = JSON.parse(savedHist);
      } else {
        state.history = [];
      }
    } catch(err) {
      state.history = [];
    }
    if (sidebarHistoryCount) sidebarHistoryCount.textContent = state.history.length;

    const savedCounter = localStorage.getItem('martk_folio_counter');
    if (savedCounter) {
      state.folioCounter = parseInt(savedCounter) || 1;
    }

    state.business.docNumber = formatFolioNumber(state.folioCounter);
    if (posDocNumber) posDocNumber.textContent = state.business.docNumber;
    if (inputDocNumber) inputDocNumber.value = state.business.docNumber;
    if (inputFolioCounter) inputFolioCounter.value = state.folioCounter;
  }

  function clearAllHistory() {
    if (confirm('¿Estás seguro de vaciar todo el historial guardado?')) {
      state.history = [];
      state.folioCounter = 1;
      localStorage.setItem('martk_folio_counter', '1');
      state.business.docNumber = formatFolioNumber(1);
      if (posDocNumber) posDocNumber.textContent = state.business.docNumber;
      if (inputDocNumber) inputDocNumber.value = state.business.docNumber;
      if (inputFolioCounter) inputFolioCounter.value = '1';

      saveHistoryToStorage();
      renderHistoryTable();
      updateCalculationsAndPreview();
      showToast('Historial vaciado completamente.', 'info');
    }
  }

  // --- DOWNLOAD TICKET IMAGE ---
  function downloadTicketAsImage() {
    if (typeof html2canvas === 'undefined') {
      showToast('Librería de imagen no lista.', 'info');
      return;
    }

    showToast('Generando imagen del ticket...', 'info');

    html2canvas(ticketCard, {
      scale: 2.5,
      useCORS: true,
      backgroundColor: '#FFFFFF',
      logging: false
    }).then(canvas => {
      const image = canvas.toDataURL('image/png');
      const link = document.createElement('a');
      const fileNameStr = (state.client.name || 'Contacto').replace(/[^a-zA-Z0-9]/g, '_');
      const docTypePrefix = state.docType === 'ingreso' ? 'Recibo' : (state.docType === 'egreso' ? 'Egreso' : 'Factura');
      const numStr = (state.business.docNumber || '001').replace(/[^a-zA-Z0-9]/g, '_');

      link.download = `MARTK_${docTypePrefix}_${numStr}_${fileNameStr}.png`;
      link.href = image;
      link.click();

      incrementFolioCounter();
      updateCalculationsAndPreview();
      showToast(`Imagen descargada. Próximo folio: ${state.business.docNumber}`, 'success');
    }).catch(err => {
      showToast('Error al generar la imagen.', 'info');
    });
  }

  // --- WHATSAPP SHARING ---
  function shareViaWhatsapp() {
    const c = state.business.currency || '$';
    const rate = state.exchange.rate || 1;
    const fmtBs = num => `Bs. ${num.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    const fmtInputCurr = num => `${c} ${num.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

    let msg = `*${state.business.docTitle.toUpperCase()} ${state.business.docNumber}*\n`;
    if (state.business.name) msg += `*${state.business.name}*\n`;
    msg += `-----------------------------------\n`;
    msg += `*Cliente:* ${state.client.name || 'Cliente Mostrador'}\n`;
    if (state.client.id) msg += `*Doc:* ${state.client.id}\n`;
    msg += `*Fecha:* ${state.client.date} ${state.client.time}\n`;
    msg += `*Forma de Pago:* ${state.client.paymentForm}\n`;

    if (state.docType === 'venta') {
      msg += `-----------------------------------\n*PRODUCTOS:*\n`;
      state.items.forEach(item => {
        if (item.desc || item.unitPrice > 0) {
          msg += `- *${item.cant}x* ${item.desc} -> ${fmtInputCurr(item.cant * item.unitPrice)}\n`;
        }
      });
      msg += `-----------------------------------\n`;
      msg += `*TOTAL A PAGAR: ${fmtInputCurr(state.totals.grandTotal)} USD*\n`;
      msg += `*EQUIVALENTE BS:* ${fmtBs(state.totals.grandTotal * rate)}\n`;
      msg += `*Tasa Ref:* ${rate.toFixed(2)} Bs.\n`;
    } else {
      msg += `-----------------------------------\n`;
      msg += `*Concepto:* ${state.paymentDetails.concept}\n`;
      msg += `*MONTO: ${fmtInputCurr(state.paymentDetails.amount)} USD*\n`;
      msg += `*EQUIVALENTE BS:* ${fmtBs(state.paymentDetails.amount * rate)}\n`;
    }

    if (state.options.showQR && state.suiche.phone && state.suiche.docNumber) {
      msg += `-----------------------------------\n`;
      msg += `*PAGO MÓVIL SUICHE 7B:*\n`;
      msg += `*Banco:* ${state.suiche.bank} | RIF: ${state.suiche.docType}${state.suiche.docNumber} | Tel: ${state.suiche.phone}\n`;
      msg += `*Monto a Transferir:* ${fmtBs(state.totals.grandTotal * rate)}\n`;
    }

    msg += `\nDocumento generado con MARTK POS • Desarrollado por EIZY SYSTEM`;

    const encodedText = encodeURIComponent(msg);
    let targetPhone = state.client.phone.replace(/[^0-9]/g, '');
    let waUrl = targetPhone ? `https://api.whatsapp.com/send?phone=${targetPhone}&text=${encodedText}` : `https://api.whatsapp.com/send?text=${encodedText}`;

    window.open(waUrl, '_blank');
    showToast('Abriendo WhatsApp...', 'success');
  }

  // --- SAMPLE DATA LOAD ---
  function loadSampleData() {
    state.business.name = 'MARTK SERVICIOS C.A.';
    state.business.id = 'RIF: J-301414566-2';
    state.business.address = 'Av. Principal de las Mercedes, Caracas';
    state.business.phone = 'Tel: 0414-1234567';

    state.client.name = 'Carlos Eduardo Gómez';
    state.client.id = 'V-12.345.678';
    state.client.phone = '584141234567';
    state.client.city = 'Caracas, Venezuela';
    state.client.paymentForm = 'Pago Móvil';
    state.client.salesperson = 'Caja POS 1';

    state.items = [
      { id: '101', cant: 1, desc: 'LICENCIA MARTK POS ADMIN V2.0', subtext: 'Suscripción Anual', taxRate: 0, unitPrice: 50.00 },
      { id: '102', cant: 2, desc: 'IMPRESORA TÉRMICA BLUETOOTH 80MM', subtext: 'Garantía 12 meses', taxRate: 0, unitPrice: 45.00 }
    ];

    inputBizName.value = state.business.name;
    inputBizId.value = state.business.id;
    inputBizAddress.value = state.business.address;
    inputBizPhone.value = state.business.phone;

    inputClientName.value = state.client.name;
    inputClientId.value = state.client.id;
    inputClientPhone.value = state.client.phone;
    inputClientCity.value = state.client.city;

    selectPaymentForm.value = state.client.paymentForm;
    inputSalesperson.value = state.client.salesperson;

    renderItemsList();
    updateCalculationsAndPreview();
    showToast('Datos de muestra cargados.', 'info');
  }

  // --- RESET FORM ---
  function resetForm() {
    state.client.name = '';
    state.client.id = '';
    state.client.phone = '';
    state.client.city = '';
    state.paymentDetails.concept = '';
    state.paymentDetails.amount = 0;
    state.paymentDetails.ref = '';

    state.items = [
      { id: Date.now().toString(), cant: 1, desc: '', subtext: '', taxRate: 0, unitPrice: 0 }
    ];

    inputClientName.value = '';
    inputClientId.value = '';
    inputClientPhone.value = '';
    inputClientCity.value = '';

    renderItemsList();
    updateCalculationsAndPreview();
    showToast('Formulario de ticket limpiado.', 'info');
  }

  // --- TOAST NOTIFICATION HELPERS ---
  function showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    toast.innerHTML = `
      <i class="${type === 'success' ? 'fa-solid fa-circle-check' : 'fa-solid fa-circle-info'}"></i>
      <span>${message}</span>
    `;

    container.appendChild(toast);

    setTimeout(() => {
      toast.style.opacity = '0';
      toast.style.transition = 'opacity 0.2s ease';
      setTimeout(() => toast.remove(), 200);
    }, 3000);
  }

  function escapeHtml(str) {
    if (!str) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }

  // --- BACKUP & RESTORE DATA SYSTEM ---
  function exportDataBackup() {
    const backupData = {
      app: 'MARTK_POS',
      version: '3.0.0',
      exportDate: new Date().toISOString(),
      settings: JSON.parse(localStorage.getItem('martk_settings_permanent') || '{}'),
      products: state.productsCatalog,
      clients: state.clientsCatalog,
      history: state.history,
      cotizaciones: state.cotizaciones,
      proyectos: state.proyectos,
      galeria: state.galeria,
      services: state.servicesCatalog,
      materials: state.materialsCatalog,
      suppliers: state.suppliersCatalog,
      sellers: state.sellersCatalog,
      cashMovements: state.cashMovements,
      cuentasPorCobrar: state.cuentasPorCobrar,
      folioCounter: state.folioCounter
    };

    const blob = new Blob([JSON.stringify(backupData, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    const dateStr = new Date().toISOString().split('T')[0];
    a.href = url;
    a.download = `MARTK_Respaldo_${dateStr}.json`;
    a.click();
    URL.revokeObjectURL(url);
    showToast('Respaldo exportado exitosamente en JSON.', 'success');
  }

  function importDataBackup(file) {
    if (!file) return;
    const reader = new FileReader();
    reader.onload = function(e) {
      try {
        const data = JSON.parse(e.target.result);
        if (!data || typeof data !== 'object') throw new Error('Formato inválido');

        if (data.products && Array.isArray(data.products)) {
          state.productsCatalog = data.products;
          localStorage.setItem('martk_products', JSON.stringify(data.products));
        }

        if (data.clients && Array.isArray(data.clients)) {
          state.clientsCatalog = data.clients;
          localStorage.setItem('martk_clients', JSON.stringify(data.clients));
        }

        if (data.history && Array.isArray(data.history)) {
          state.history = data.history;
          localStorage.setItem('martk_history_records', JSON.stringify(data.history));
        }

        if (data.cotizaciones && Array.isArray(data.cotizaciones)) {
          state.cotizaciones = data.cotizaciones;
          localStorage.setItem('martk_quotes', JSON.stringify(data.cotizaciones));
        }

        if (data.proyectos && Array.isArray(data.proyectos)) {
          state.proyectos = data.proyectos;
          localStorage.setItem('martk_projects', JSON.stringify(data.proyectos));
        }

        if (data.galeria && Array.isArray(data.galeria)) {
          state.galeria = data.galeria;
          localStorage.setItem('martk_gallery', JSON.stringify(data.galeria));
        }

        if (data.folioCounter) {
          state.folioCounter = parseInt(data.folioCounter) || 1;
          if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_folio_counter', state.folioCounter.toString()); } else { localStorage.setItem('martk_folio_counter', state.folioCounter.toString()); }
        }

        if (data.settings && typeof data.settings === 'object') {
          applySettingsObject(data.settings);
          localStorage.setItem('martk_settings_permanent', JSON.stringify(data.settings));
        }

        renderProductsTable();
        renderClientsTable();
        renderHistoryTable();
        renderQuotesHistory();
        renderProjectsPipeline();
        renderGallery();
        updateCalculationsAndPreview();
        showToast('¡Respaldo importado y restaurado exitosamente!', 'success');
      } catch (err) {
        showToast('Error al leer el archivo de respaldo JSON.', 'info');
      }
    };
    reader.readAsText(file);
  }

  // ==========================================================================
  // MÓDULO 6: COTIZACIONES & PRESUPUESTOS (STITCH PUBLICRAFT & VECTOR ENGINE)
  // ==========================================================================

  function initActiveQuote(existing) {
    if (existing) {
      state.activeQuote = JSON.parse(JSON.stringify(existing));
      if (!state.activeQuote.vectorFiles) state.activeQuote.vectorFiles = getDefaultVectorFiles();
      if (!state.activeQuote.facadeSurvey) state.activeQuote.facadeSurvey = getDefaultFacadeSurvey();
    } else {
      const qNum = (state.cotizaciones.length + 1).toString().padStart(3, '0');
      state.activeQuote = {
        id: Date.now(),
        folio: `COT-${qNum}`,
        title: 'Aviso Corpóreo Acrílico 3D con Luz Neón Flex + 2 Pendones Frontlight',
        clientName: 'Boutique Velvet & Co.',
        clientPhone: '584141234567',
        date: new Date().toISOString().split('T')[0],
        validityDays: 15,
        items: [
          { type: 'material', desc: 'Acrílico Espejo Dorado 3mm + Base MDF 12mm', cant: 1, unitCost: 45.00, unitPrice: 110.00 },
          { type: 'material', desc: 'Módulos Neón Flex LED 12V Siliconado IP67 (metros)', cant: 12, unitCost: 4.50, unitPrice: 10.00 },
          { type: 'corte', desc: 'Corte CNC Router y grabado de contornos 1:1', cant: 3, unitCost: 10.00, unitPrice: 25.00 },
          { type: 'material', desc: 'Pendón Frontlight 13oz 3x2m con ojetes y refuerzo', cant: 2, unitCost: 20.00, unitPrice: 45.00 },
          { type: 'instalacion', desc: 'Montaje Técnico en Altura (Andamio + Eléctrico 220V)', cant: 1, unitCost: 35.00, unitPrice: 85.00 }
        ],
        vectorFiles: getDefaultVectorFiles(),
        facadeSurvey: getDefaultFacadeSurvey(),
        status: 'Borrador'
      };
    }

    const tag = document.getElementById('quote-number-tag');
    const titleInput = document.getElementById('quote-title');
    const cName = document.getElementById('quote-client-name');
    const cPhone = document.getElementById('quote-client-phone');
    const qDate = document.getElementById('quote-date');
    const qVal = document.getElementById('quote-validity');
    const sDim = document.getElementById('survey-dim');
    const sWall = document.getElementById('survey-wall');
    const sPower = document.getElementById('survey-power');

    if (tag) tag.textContent = state.activeQuote.folio;
    if (titleInput) titleInput.value = state.activeQuote.title;
    if (cName) cName.value = state.activeQuote.clientName;
    if (cPhone) cPhone.value = state.activeQuote.clientPhone;
    if (qDate) qDate.value = state.activeQuote.date;
    if (qVal) qVal.value = state.activeQuote.validityDays;

    if (state.activeQuote.facadeSurvey) {
      if (sDim) sDim.value = state.activeQuote.facadeSurvey.dim || '380 x 140 cm';
      if (sWall) sWall.value = state.activeQuote.facadeSurvey.wall || 'Muro Concreto / Broca 3/8';
      if (sPower) sPower.value = state.activeQuote.facadeSurvey.power || 'Punto 220V + Anclajes';
    }

    renderQuoteItemsTable();
    renderVectorFilesList();
    renderFacadeSurveyGrid();
    recalcQuoteTotals();
  }

  function getDefaultVectorFiles() {
    return [
      {
        id: 'vec-1',
        name: 'aviso_corporeo_velvet_letras_3d.dxf',
        type: 'dxf',
        size: '4.2 MB',
        machine: 'Router 12mm MDF + Acrílico 3mm',
        validStatus: 'Vector Validado 1:1'
      },
      {
        id: 'vec-2',
        name: 'caja_luz_perfil_aluminio.ai',
        type: 'ai',
        size: '18.6 MB',
        machine: 'Trazos en Curvas CMYK',
        validStatus: 'Listo para Nesting'
      }
    ];
  }

  function getDefaultFacadeSurvey() {
    return {
      dim: '380 x 140 cm',
      wall: 'Muro Concreto / Broca 3/8',
      power: 'Punto 220V + Anclajes',
      photos: [
        {
          title: 'Fachada Principal con Cotas',
          cota: '380 x 140 cm',
          note: 'Punto 220V + Anclajes listos',
          url: 'https://images.unsplash.com/photo-1541888946425-d0fbb186c5f7?auto=format&fit=crop&w=600&q=80'
        },
        {
          title: 'Simulación Render 3D Diurno',
          cota: 'Render Aprobado',
          note: 'Visto bueno del cliente',
          url: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=600&q=80'
        }
      ]
    };
  }

  function renderVectorFilesList() {
    const container = document.getElementById('vector-files-list');
    if (!container || !state.activeQuote) return;
    container.innerHTML = '';

    const files = state.activeQuote.vectorFiles || [];
    if (files.length === 0) {
      container.innerHTML = '<p style="font-size:0.75rem; color:#94A3B8; padding:0.5rem 0;">No hay archivos vectoriales adjuntos. Toca "Cargar Archivo Vectorial" para registrar planos DXF, DWG o AI.</p>';
      return;
    }

    files.forEach((f, idx) => {
      const item = document.createElement('div');
      item.className = 'vector-file-item';
      item.innerHTML = `
        <div style="display:flex; align-items:center; gap:0.75rem; min-width:0; flex:1;">
          <div class="vector-badge ${escapeHtml(f.type || 'dxf')}">${(f.type || 'DXF').toUpperCase()}</div>
          <div class="vector-info">
            <span class="vector-name">${escapeHtml(f.name)}</span>
            <div class="vector-meta">
              <span>${escapeHtml(f.size || '1.0 MB')}</span>
              <span>•</span>
              <span>${escapeHtml(f.machine || 'Router CNC')}</span>
            </div>
            <span class="vector-valid-badge">
              <i class="fa-solid fa-circle-check"></i> ${escapeHtml(f.validStatus || 'Validado')}
            </span>
          </div>
        </div>
        <div style="display:flex; align-items:center; gap:0.25rem;">
          <button type="button" class="btn btn-xs btn-outline btn-del-vector" data-idx="${idx}" title="Eliminar Plano">
            <i class="fa-solid fa-trash text-error"></i>
          </button>
        </div>
      `;
      container.appendChild(item);
    });

    container.querySelectorAll('.btn-del-vector').forEach(btn => {
      btn.addEventListener('click', e => {
        const i = parseInt(btn.dataset.idx);
        state.activeQuote.vectorFiles.splice(i, 1);
        renderVectorFilesList();
        showToast('Archivo vectorial removido.', 'info');
      });
    });
  }

  function renderFacadeSurveyGrid() {
    const grid = document.getElementById('facade-survey-grid');
    if (!grid || !state.activeQuote) return;
    grid.innerHTML = '';

    const photos = (state.activeQuote.facadeSurvey && state.activeQuote.facadeSurvey.photos) || [];
    photos.forEach(p => {
      const card = document.createElement('div');
      card.className = 'facade-card';
      card.innerHTML = `
        <img src="${p.url}" alt="${escapeHtml(p.title)}">
        <div class="facade-card-overlay">
          <span class="facade-cota-tag">${escapeHtml(p.cota)}</span>
          <strong style="font-size:0.8rem; text-shadow:0 1px 3px rgba(0,0,0,0.8);">${escapeHtml(p.title)}</strong>
          <span style="font-size:0.7rem; opacity:0.9; text-shadow:0 1px 2px rgba(0,0,0,0.8);">${escapeHtml(p.note)}</span>
        </div>
      `;
      grid.appendChild(card);
    });
  }

  function updateQuoteKPIs() {
    let pipelineTotal = 0;
    let activeQuotes = 0;
    let approvedQuotes = 0;

    state.cotizaciones.forEach(q => {
      if (q.status !== 'Rechazado') {
        pipelineTotal += (q.totalClient || 0);
        activeQuotes++;
      }
      if (q.status === 'Aprobado') {
        approvedQuotes++;
      }
    });

    const closeRate = state.cotizaciones.length > 0 ? Math.round((approvedQuotes / state.cotizaciones.length) * 100) : 0;

    const elTotal = document.getElementById('kpi-quote-pipeline-total');
    const elActives = document.getElementById('kpi-quote-active-count');
    const elRate = document.getElementById('kpi-quote-close-rate');
    const elApproved = document.getElementById('kpi-quote-approved-count');
    const elRateLbl = document.getElementById('kpi-quote-rate-label');

    if (elTotal) elTotal.textContent = `$${pipelineTotal.toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    if (elActives) elActives.textContent = `${activeQuotes} activas en USD`;
    if (elRate) elRate.textContent = `${closeRate}%`;
    if (elApproved) elApproved.textContent = `${approvedQuotes} aprobadas este mes`;
    if (elRateLbl) elRateLbl.textContent = closeRate >= 50 ? 'Excelente tasa de cierre' : 'Efectividad comercial';

    const countAll = document.getElementById('quote-count-all');
    const countAp = document.getElementById('quote-count-aprobadas');
    const countEnv = document.getElementById('quote-count-enviadas');
    const countBorr = document.getElementById('quote-count-borradores');

    if (countAll) countAll.textContent = state.cotizaciones.length;
    if (countAp) countAp.textContent = state.cotizaciones.filter(q => q.status === 'Aprobado').length;
    if (countEnv) countEnv.textContent = state.cotizaciones.filter(q => q.status === 'Enviada').length;
    if (countBorr) countBorr.textContent = state.cotizaciones.filter(q => q.status === 'Borrador').length;
  }

  function loadCotizacionesFromStorage() {
    try {
      const saved = localStorage.getItem('martk_quotes');
      state.cotizaciones = saved ? JSON.parse(saved) : [];
      renderQuotesHistory();
    } catch(err) {
      state.cotizaciones = [];
      renderQuotesHistory();
    }
  }

  function saveCotizacionesToStorage() {
    if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_quotes', state.cotizaciones); } else { localStorage.setItem('martk_quotes', JSON.stringify(state.cotizaciones)); }
    updateQuoteKPIs();
  }

  function renderQuoteItemsTable() {
    const tbody = document.getElementById('quote-items-body');
    if (!tbody || !state.activeQuote) return;
    tbody.innerHTML = '';

    state.activeQuote.items.forEach((item, idx) => {
      const subCost = (item.cant || 0) * (item.unitCost || 0);
      const subPrice = (item.cant || 0) * (item.unitPrice || 0);

      const tr = document.createElement('tr');
      tr.innerHTML = `
        <td>
          <select class="q-row-type" data-idx="${idx}" style="padding:0.35rem; font-size:0.75rem; border:none; border-bottom:1px solid #CBD5E1; background:transparent;">
            <option value="material" ${item.type === 'material' ? 'selected' : ''}>Material</option>
            <option value="corte" ${item.type === 'corte' ? 'selected' : ''}>Corte CNC</option>
            <option value="instalacion" ${item.type === 'instalacion' ? 'selected' : ''}>Instalación</option>
            <option value="diseno" ${item.type === 'diseno' ? 'selected' : ''}>Diseño / CAD</option>
            <option value="otro" ${item.type === 'otro' ? 'selected' : ''}>Otro</option>
          </select>
        </td>
        <td>
          <input type="text" class="q-row-desc" data-idx="${idx}" value="${escapeHtml(item.desc)}" style="width:100%; padding:0.35rem; font-size:0.85rem; border:none; border-bottom:1px solid #CBD5E1; background:transparent;">
        </td>
        <td>
          <input type="number" class="q-row-cant" data-idx="${idx}" min="1" step="0.5" value="${item.cant}" style="width:100%; padding:0.35rem; font-size:0.85rem; text-align:center; border:none; border-bottom:1px solid #CBD5E1; background:transparent;">
        </td>
        <td class="td-cost">
          <input type="number" class="q-row-cost" data-idx="${idx}" min="0" step="0.5" value="${item.unitCost}" style="width:100%; padding:0.35rem; font-size:0.85rem; color:#991B1B; border:none; border-bottom:1px solid #CBD5E1; background:transparent;">
        </td>
        <td class="td-cost" style="font-weight:700; color:#991B1B;">
          $${subCost.toFixed(2)}
        </td>
        <td>
          <input type="number" class="q-row-price" data-idx="${idx}" min="0" step="0.5" value="${item.unitPrice}" style="width:100%; padding:0.35rem; font-size:0.85rem; font-weight:700; color:#2563EB; border:none; border-bottom:1px solid #CBD5E1; background:transparent;">
        </td>
        <td style="font-weight:800; color:#0F172A;">
          $${subPrice.toFixed(2)}
        </td>
        <td style="text-align:center;">
          <button type="button" class="btn-del-quote-row" data-idx="${idx}" style="background:transparent; border:none; color:#EF4444; cursor:pointer; font-size:1rem;"><i class="fa-solid fa-trash-can"></i></button>
        </td>
      `;
      tbody.appendChild(tr);
    });

    tbody.querySelectorAll('.q-row-type').forEach(el => {
      el.addEventListener('change', e => {
        const i = parseInt(e.target.dataset.idx);
        state.activeQuote.items[i].type = e.target.value;
      });
    });
    tbody.querySelectorAll('.q-row-desc').forEach(el => {
      el.addEventListener('input', e => {
        const i = parseInt(e.target.dataset.idx);
        state.activeQuote.items[i].desc = e.target.value;
      });
    });
    tbody.querySelectorAll('.q-row-cant').forEach(el => {
      el.addEventListener('input', e => {
        const i = parseInt(e.target.dataset.idx);
        state.activeQuote.items[i].cant = parseFloat(e.target.value) || 0;
        recalcQuoteTotals();
        renderQuoteItemsTable();
      });
    });
    tbody.querySelectorAll('.q-row-cost').forEach(el => {
      el.addEventListener('input', e => {
        const i = parseInt(e.target.dataset.idx);
        state.activeQuote.items[i].unitCost = parseFloat(e.target.value) || 0;
        recalcQuoteTotals();
      });
    });
    tbody.querySelectorAll('.q-row-price').forEach(el => {
      el.addEventListener('input', e => {
        const i = parseInt(e.target.dataset.idx);
        state.activeQuote.items[i].unitPrice = parseFloat(e.target.value) || 0;
        recalcQuoteTotals();
      });
    });
    tbody.querySelectorAll('.btn-del-quote-row').forEach(el => {
      el.addEventListener('click', e => {
        const i = parseInt(el.dataset.idx);
        state.activeQuote.items.splice(i, 1);
        renderQuoteItemsTable();
        recalcQuoteTotals();
      });
    });

    applyQuoteProfitModeVisibility();
  }

  function recalcQuoteTotals() {
    if (!state.activeQuote) return;
    let totalClient = 0;
    let totalCost = 0;

    state.activeQuote.items.forEach(it => {
      totalClient += (it.cant || 0) * (it.unitPrice || 0);
      totalCost += (it.cant || 0) * (it.unitCost || 0);
    });

    const gain = totalClient - totalCost;
    const marginPct = totalClient > 0 ? (gain / totalClient) * 100 : 0;
    const rate = state.exchange.rate || 1;
    const totalBcv = totalClient * rate;
    const anticipo = totalClient * 0.50;

    state.activeQuote.totalClient = totalClient;
    state.activeQuote.totalCost = totalCost;
    state.activeQuote.gain = gain;
    state.activeQuote.marginPct = marginPct;
    state.activeQuote.anticipo = anticipo;

    const elClient = document.getElementById('quote-view-total-client');
    const elBcv = document.getElementById('quote-view-total-bcv');
    const elCost = document.getElementById('quote-view-total-cost');
    const elGain = document.getElementById('quote-view-gain');
    const elMargin = document.getElementById('quote-view-margin');
    const elAnticipo = document.getElementById('quote-anticipo-val');

    if (elClient) elClient.textContent = `$${totalClient.toFixed(2)} USD`;
    if (elBcv) elBcv.textContent = `Bs. ${totalBcv.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    if (elCost) elCost.textContent = `$${totalCost.toFixed(2)} USD`;
    if (elGain) elGain.textContent = `$${gain.toFixed(2)} USD`;
    if (elMargin) elMargin.textContent = `${marginPct.toFixed(1)}%`;
    if (elAnticipo) elAnticipo.textContent = `$${anticipo.toFixed(2)} USD`;
  }

  function applyQuoteProfitModeVisibility() {
    const show = state.quoteProfitMode;
    document.querySelectorAll('.quote-profit-block').forEach(el => {
      if (show) el.classList.remove('hidden');
      else el.classList.add('hidden');
    });
    document.querySelectorAll('.th-cost, .td-cost').forEach(el => {
      if (show) el.style.display = '';
      else el.style.display = 'none';
    });
  }

  function saveCurrentQuote() {
    if (!state.activeQuote) return;
    const titleInput = document.getElementById('quote-title');
    const cName = document.getElementById('quote-client-name');
    const cPhone = document.getElementById('quote-client-phone');
    const qDate = document.getElementById('quote-date');
    const qVal = document.getElementById('quote-validity');
    const sDim = document.getElementById('survey-dim');
    const sWall = document.getElementById('survey-wall');
    const sPower = document.getElementById('survey-power');

    state.activeQuote.title = titleInput ? cleanInputText(titleInput.value) : 'Presupuesto de Publicidad';
    state.activeQuote.clientName = cName ? cleanInputText(cName.value) : 'Cliente Mostrador';
    state.activeQuote.clientPhone = cPhone ? cleanPhoneInput(cPhone.value) : '';
    state.activeQuote.date = qDate ? qDate.value : new Date().toISOString().split('T')[0];
    state.activeQuote.validityDays = qVal ? parseInt(qVal.value) || 15 : 15;

    if (!state.activeQuote.facadeSurvey) state.activeQuote.facadeSurvey = {};
    if (sDim) state.activeQuote.facadeSurvey.dim = sDim.value;
    if (sWall) state.activeQuote.facadeSurvey.wall = sWall.value;
    if (sPower) state.activeQuote.facadeSurvey.power = sPower.value;

    recalcQuoteTotals();

    const existingIdx = state.cotizaciones.findIndex(q => q.id === state.activeQuote.id);
    if (existingIdx !== -1) {
      state.cotizaciones[existingIdx] = JSON.parse(JSON.stringify(state.activeQuote));
    } else {
      state.cotizaciones.unshift(JSON.parse(JSON.stringify(state.activeQuote)));
    }

    saveCotizacionesToStorage();
    renderQuotesHistory();
    showToast(`Presupuesto ${state.activeQuote.folio} guardado correctamente.`, 'success');
  }

  function renderQuotesHistory() {
    const container = document.getElementById('quotes-history-cards');
    if (!container) return;
    const search = document.getElementById('search-quotes');
    const qStr = (search ? search.value : '').toLowerCase().trim();
    container.innerHTML = '';

    const list = state.cotizaciones.filter(q => {
      if (state.quoteStatusFilter && state.quoteStatusFilter !== 'all' && q.status !== state.quoteStatusFilter) return false;
      if (!qStr) return true;
      return (q.title || '').toLowerCase().includes(qStr) ||
             (q.clientName || '').toLowerCase().includes(qStr) ||
             (q.folio || '').toLowerCase().includes(qStr);
    });

    if (list.length === 0) {
      container.innerHTML = '<div style="text-align:center; padding:2.5rem 1rem; color:#94A3B8;"><i class="fa-solid fa-file-circle-question" style="font-size:2rem; margin-bottom:0.5rem; display:block;"></i>No hay cotizaciones registradas en este estado.</div>';
      return;
    }

    list.forEach(q => {
      const card = document.createElement('div');
      card.className = 'quote-stitch-card';

      // Status Badge Style
      let statusClass = 'status-presupuesto';
      let statusIcon = 'fa-pen';
      let statusLabel = q.status || 'Borrador';

      if (q.status === 'Aprobado') {
        statusClass = 'status-aprobado';
        statusIcon = 'fa-circle-check';
        statusLabel = 'Aprobada';
      } else if (q.status === 'Enviada') {
        statusClass = 'status-envio';
        statusIcon = 'fa-paper-plane';
        statusLabel = 'Enviada';
      }

      // Initial Letters for Avatar
      const initials = (q.clientName || 'Cliente').split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();
      const totalFormatted = (q.totalClient || 0).toLocaleString('en-US', { minimumFractionDigits: 2, maximumFractionDigits: 2 });

      card.innerHTML = `
        <div class="quote-stitch-header">
          <div style="min-width:0; flex:1;">
            <div class="quote-meta-strip">
              <span style="color:#2563EB; font-weight:800;">${escapeHtml(q.folio)}</span>
              <span>•</span>
              <span>${q.date || 'Hoy'}</span>
            </div>
            <h3 class="quote-stitch-title">${escapeHtml(q.title || 'Proyecto')}</h3>
            <p class="quote-stitch-sub">${escapeHtml(q.items ? q.items.map(it => it.desc).slice(0, 2).join(' • ') : 'Servicios de Publicidad')}</p>
          </div>
          <span class="status-badge ${statusClass}" style="flex-shrink:0;">
            <i class="fa-solid ${statusIcon}"></i> ${statusLabel}
          </span>
        </div>

        <div class="quote-client-subbox">
          <div style="display:flex; align-items:center; gap:0.6rem; min-width:0;">
            <div class="avatar-initials">${initials}</div>
            <div style="min-width:0;">
              <strong style="font-size:0.85rem; color:#0F172A; display:block; white-space:nowrap; overflow:hidden; text-overflow:ellipsis;">
                ${escapeHtml(q.clientName || 'Cliente Mostrador')}
              </strong>
              <span style="font-size:0.75rem; color:#64748B;">
                ${q.status === 'Aprobado' ? '<i class="fa-solid fa-signature" style="color:#059669;"></i> Firma digital registrada' : 'Presupuesto formal'}
              </span>
            </div>
          </div>
          <div style="text-align:right; flex-shrink:0;">
            <span style="font-size:0.68rem; text-transform:uppercase; color:#64748B; font-weight:700; display:block;">TOTAL</span>
            <strong style="font-size:1.15rem; color:#0F172A; font-weight:800;">$${totalFormatted}</strong>
          </div>
        </div>

        <div class="quote-stitch-actions">
          <button type="button" class="btn btn-stitch-primary btn-q-convert" data-id="${q.id}">
            <i class="fa-solid fa-rocket"></i> A Proyecto
          </button>
          <button type="button" class="btn btn-stitch-secondary btn-q-view" data-id="${q.id}">
            <i class="fa-solid fa-file-pdf"></i> Ver PDF / Firma
          </button>
          <button type="button" class="btn btn-outline btn-q-edit" data-id="${q.id}" style="flex:0 0 44px; padding:0;" title="Editar">
            <i class="fa-solid fa-pen"></i>
          </button>
          <button type="button" class="btn btn-outline btn-q-wa" data-id="${q.id}" style="flex:0 0 44px; padding:0; color:#25D366;" title="Enviar WhatsApp">
            <i class="fa-brands fa-whatsapp"></i>
          </button>
          <button type="button" class="btn btn-outline btn-q-del" data-id="${q.id}" style="flex:0 0 44px; padding:0; color:#EF4444;" title="Eliminar">
            <i class="fa-solid fa-trash"></i>
          </button>
        </div>
      `;

      container.appendChild(card);
    });

    container.querySelectorAll('.btn-q-convert').forEach(b => {
      b.addEventListener('click', () => convertQuoteToProject(b.dataset.id));
    });
    container.querySelectorAll('.btn-q-view').forEach(b => {
      b.addEventListener('click', () => {
        const q = state.cotizaciones.find(item => item.id == b.dataset.id);
        if (q) {
          initActiveQuote(q);
          switchView('view-cotizacion-detalle');
        }
      });
    });
    container.querySelectorAll('.btn-q-edit').forEach(b => {
      b.addEventListener('click', () => {
        const q = state.cotizaciones.find(item => item.id == b.dataset.id);
        if (q) {
          initActiveQuote(q);
          switchView('view-cotizacion-detalle');
          showToast(`Cargada ${q.folio} en editor.`, 'info');
        }
      });
    });
    container.querySelectorAll('.btn-q-wa').forEach(b => {
      b.addEventListener('click', () => {
        const q = state.cotizaciones.find(item => item.id == b.dataset.id);
        if (q) shareQuoteViaWhatsapp(q);
      });
    });
    container.querySelectorAll('.btn-q-del').forEach(b => {
      b.addEventListener('click', () => {
        if (confirm('¿Eliminar esta cotización?')) {
          state.cotizaciones = state.cotizaciones.filter(item => item.id != b.dataset.id);
          saveCotizacionesToStorage();
          renderQuotesHistory();
          showToast('Cotización eliminada.', 'info');
        }
      });
    });
  }

  function initSignatureCanvas() {
    const canvas = document.getElementById('quote-signature-canvas');
    const placeholder = document.getElementById('signature-placeholder');
    const btnClear = document.getElementById('btn-clear-signature');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');

    function resizeCanvas() {
      const rect = canvas.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        canvas.width = rect.width;
        canvas.height = rect.height;
        ctx.strokeStyle = '#0F172A';
        ctx.lineWidth = 2.2;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
      }
    }

    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    function startDraw(e) {
      isDrawingSignature = true;
      if (placeholder) placeholder.style.display = 'none';
      const rect = canvas.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      ctx.beginPath();
      ctx.moveTo(clientX - rect.left, clientY - rect.top);
    }

    function draw(e) {
      if (!isDrawingSignature) return;
      e.preventDefault();
      const rect = canvas.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      ctx.lineTo(clientX - rect.left, clientY - rect.top);
      ctx.stroke();
    }

    function stopDraw() {
      if (!isDrawingSignature) return;
      isDrawingSignature = false;
      if (state.activeQuote) {
        state.activeQuote.signature = canvas.toDataURL('image/png');
      }
    }

    canvas.addEventListener('mousedown', startDraw);
    canvas.addEventListener('mousemove', draw);
    canvas.addEventListener('mouseup', stopDraw);
    canvas.addEventListener('mouseleave', stopDraw);

    canvas.addEventListener('touchstart', startDraw, { passive: false });
    canvas.addEventListener('touchmove', draw, { passive: false });
    canvas.addEventListener('touchend', stopDraw);

    if (btnClear) {
      btnClear.addEventListener('click', () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        if (placeholder) placeholder.style.display = 'flex';
        if (state.activeQuote) state.activeQuote.signature = null;
      });
    }

    signatureCanvasInited = true;
  }

  function openQuoteSheetModal(quote) {
    if (quote) initActiveQuote(quote);
    switchView('view-cotizacion-detalle');
    const modal = document.getElementById('modal-quote-sheet');
    if (!modal) return;

    // Logo oficial de empresa si existe
    const logoImg = document.getElementById('qsheet-logo-img');
    if (logoImg) {
      if (state.business.logo) {
        logoImg.src = state.business.logo;
        logoImg.style.display = 'block';
      } else {
        logoImg.style.display = 'none';
      }
    }

    const bName = document.getElementById('qsheet-biz-name');
    const bPhone = document.getElementById('qsheet-biz-phone');
    const bAddress = document.getElementById('qsheet-biz-address');
    if (bName) bName.textContent = state.business.name || 'TU NEGOCIO DE PUBLICIDAD';
    if (bPhone) bPhone.textContent = state.business.phone ? `Tel / WhatsApp: ${state.business.phone}` : '';
    if (bAddress) bAddress.textContent = state.business.address ? `Dirección: ${state.business.address}` : '';

    document.getElementById('qsheet-folio').textContent = quote.folio;
    document.getElementById('qsheet-date').textContent = `Emisión: ${quote.date}`;
    document.getElementById('qsheet-validity-text').textContent = `Vence: ${quote.validityDays || 15} días`;
    document.getElementById('qsheet-client-name').textContent = quote.clientName || 'Cliente';
    document.getElementById('qsheet-client-phone').textContent = quote.clientPhone || '-';
    document.getElementById('qsheet-title').textContent = quote.title || 'Proyecto de Publicidad';

    // Ficha de materiales incluidos en el membrete
    const materialsRow = document.getElementById('qsheet-materials-row');
    if (materialsRow) {
      materialsRow.innerHTML = `
        <span class="materials-pill"><span class="materials-dot" style="background:#F59E0B;"></span>Acrílico Espejo Dorado</span>
        <span class="materials-pill"><span class="materials-dot" style="background:#10B981;"></span>Puntera LED Neón IP67</span>
        <span class="materials-pill"><span class="materials-dot" style="background:#3B82F6;"></span>Lona Front 13oz Sellada</span>
      `;
    }

    const tbody = document.getElementById('qsheet-items-body');
    tbody.innerHTML = '';
    (quote.items || []).forEach((it, idx) => {
      const sub = (it.cant || 0) * (it.unitPrice || 0);
      const tr = document.createElement('tr');
      tr.style.borderBottom = '1px solid #E2E8F0';
      tr.innerHTML = `
        <td style="padding:0.6rem 0.8rem; font-weight:700; color:#64748B;">${idx + 1}</td>
        <td style="padding:0.6rem 0.8rem;">
          <strong style="color:#0F172A;">${escapeHtml(it.desc)}</strong>
        </td>
        <td style="padding:0.6rem 0.8rem; text-align:center; font-weight:700;">${it.cant}</td>
        <td style="padding:0.6rem 0.8rem; text-align:right;">$${(it.unitPrice || 0).toFixed(2)}</td>
        <td style="padding:0.6rem 0.8rem; text-align:right; font-weight:700; color:#0F172A;">$${sub.toFixed(2)}</td>
      `;
      tbody.appendChild(tr);
    });

    const rate = state.exchange.rate || 1;
    const totalClient = quote.totalClient || 0;
    const anticipo = totalClient * 0.50;
    const bcvVal = totalClient * rate;

    const elTotalUsd = document.getElementById('qsheet-total-usd');
    const elAnticipoUsd = document.getElementById('qsheet-anticipo-usd');
    const elTotalBcv = document.getElementById('qsheet-total-bcv');
    const elRateNote = document.getElementById('qsheet-rate-note');

    if (elTotalUsd) elTotalUsd.textContent = `$${totalClient.toFixed(2)} USD`;
    if (elAnticipoUsd) elAnticipoUsd.textContent = `$${anticipo.toFixed(2)} USD`;
    if (elTotalBcv) elTotalBcv.textContent = `Equivalente: Bs. ${bcvVal.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    if (elRateNote) elRateNote.textContent = `Tasa Oficial BCV de referencia: ${rate.toFixed(2)} Bs. / USD.`;

    // Cuentas bancarias de anticipos
    const bankArea = document.getElementById('bank-info-textarea');
    const qBankInfo = document.getElementById('qsheet-bank-info');
    if (qBankInfo) {
      qBankInfo.textContent = bankArea && bankArea.value.trim() ? bankArea.value.trim() : 'Pago Móvil: Banesco (0134) • C.I: 12.345.678 • Tel: 0414-0000000';
    }

    modal.classList.remove('hidden');

    setTimeout(() => {
      if (!signatureCanvasInited) initSignatureCanvas();
    }, 150);
  }

  function shareQuoteViaWhatsapp(quote) {
    if (!quote) return;
    const rate = state.exchange.rate || 1;
    const totalClient = quote.totalClient || 0;
    const bcvVal = totalClient * rate;
    const anticipo = totalClient * 0.50;

    let msg = `*PRESUPUESTO FORMAL: ${quote.folio}*
`;
    if (state.business.name) msg += `*${state.business.name}*
`;
    msg += `-----------------------------------
`;
    msg += `*Proyecto:* ${quote.title}
`;
    msg += `*Cliente:* ${quote.clientName}
`;
    msg += `*Fecha:* ${quote.date} (Validez: ${quote.validityDays} días)
`;
    msg += `-----------------------------------
*DESGLOSE:* 
`;

    (quote.items || []).forEach(it => {
      const sub = (it.cant || 0) * (it.unitPrice || 0);
      msg += `• *${it.cant}x* ${it.desc} -> $${sub.toFixed(2)}
`;
    });

    msg += `-----------------------------------
`;
    msg += `*TOTAL DEL PROYECTO: $${totalClient.toFixed(2)} USD*
`;
    msg += `*Anticipo 50% Requerido: $${anticipo.toFixed(2)} USD*
`;
    msg += `*Equivalente BCV:* Bs. ${bcvVal.toLocaleString('es-VE', { minimumFractionDigits: 2 })}
`;
    msg += `*Condiciones:* 50% al iniciar para adquisición de materiales y corte CNC • 50% contra entrega e instalación.

`;
    
    const bankArea = document.getElementById('bank-info-textarea');
    if (bankArea && bankArea.value.trim()) {
      msg += `*Cuentas para Pago de Anticipo:*
${bankArea.value.trim()}

`;
    }

    msg += `_Cotizado con MARKT POS & Publicraft Studio_`;

    const encoded = encodeURIComponent(msg);
    const targetPhone = (quote.clientPhone || '').replace(/[^0-9]/g, '');
    const waUrl = targetPhone ? `https://api.whatsapp.com/send?phone=${targetPhone}&text=${encoded}` : `https://api.whatsapp.com/send?text=${encoded}`;
    window.open(waUrl, '_blank');
  }

  function convertQuoteToProject(quoteId) {
    const quote = state.cotizaciones.find(q => q.id == quoteId) || state.activeQuote;
    if (!quote) return;

    const pNum = (state.proyectos.length + 1).toString().padStart(3, '0');
    const newProj = {
      id: Date.now(),
      code: `PRJ-${pNum}`,
      title: quote.title || 'Trabajo de Publicidad',
      clientName: quote.clientName || 'Cliente',
      clientPhone: quote.clientPhone || '',
      address: (quote.facadeSurvey && quote.facadeSurvey.dim) ? `Fachada: ${quote.facadeSurvey.dim}` : '',
      dateStart: new Date().toISOString().split('T')[0],
      dateDeadline: new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0],
      total: quote.totalClient || 0,
      abono: 0,
      status: 'aprobado',
      pauseReason: '',
      notes: [
        { date: new Date().toLocaleString('es-ES'), text: `Proyecto creado desde cotización ${quote.folio}` }
      ],
      photos: (quote.facadeSurvey && quote.facadeSurvey.photos) || []
    };

    state.proyectos.unshift(newProj);
    saveProyectosToStorage();
    showToast(`¡Proyecto ${newProj.code} creado exitosamente!`, 'success');

    const navBtn = document.querySelector('[data-view="view-proyectos"]');
    if (navBtn) navBtn.click();
  }

  // ==========================================================================
  // MÓDULO 7: GESTIÓN DE PROYECTOS, PIPELINE & AGENDA GOOGLE CALENDAR (STITCH)
  // ==========================================================================

  function updateProjectKPIs() {
    let activeCount = 0;
    let pendingMoney = 0;
    let siteCount = 0;

    state.proyectos.forEach(p => {
      if (p.status !== 'culminado') {
        activeCount++;
        const saldo = Math.max(0, (p.total || 0) - (p.abono || 0));
        pendingMoney += saldo;
      }
      if (p.status === 'instalacion') {
        siteCount++;
      }
    });

    const elActives = document.getElementById('kpi-proj-active-count');
    const elMoney = document.getElementById('kpi-proj-pending-money');
    const elSite = document.getElementById('kpi-proj-site-count');

    if (elActives) elActives.textContent = activeCount;
    if (elMoney) elMoney.textContent = `$${pendingMoney.toFixed(2)}`;
    if (elSite) elSite.textContent = siteCount;
  }

  function loadProyectosFromStorage() {
    try {
      const saved = localStorage.getItem('martk_projects');
      if (saved) {
        state.proyectos = JSON.parse(saved);
      } else {
        state.proyectos = [
          {
            id: 2001,
            code: 'PRJ-001',
            title: 'Aviso Corpóreo Acrílico 3D con Luz Neón Flex',
            clientName: 'Boutique Velvet & Co.',
            clientPhone: '584141234567',
            address: 'Las Mercedes, Calle París, Local 4',
            dateStart: new Date().toISOString().split('T')[0],
            dateDeadline: new Date(Date.now() + 3 * 86400000).toISOString().split('T')[0],
            total: 485.00,
            abono: 242.50,
            status: 'produccion',
            pauseReason: '',
            notes: [
              { date: '16/10/2026, 09:30', text: 'Anticipo del 50% recibido por Pago Móvil.' },
              { date: '17/10/2026, 14:00', text: 'Corte de acrílico terminado. Iniciando armado de mangueras LED.' }
            ],
            photos: [
              {
                date: '17/10/2026',
                url: 'https://images.unsplash.com/photo-1541888946425-d0fbb186c5f7?auto=format&fit=crop&w=600&q=80'
              }
            ]
          },
          {
            id: 2002,
            code: 'PRJ-002',
            title: 'Letras Corpóreas 3D en Acrílico con Luz Frontal',
            clientName: 'Dra. Mariana Rivas (Clínica Dental)',
            clientPhone: '584249876543',
            address: 'Torre Empresarial, Piso 3',
            dateStart: new Date().toISOString().split('T')[0],
            dateDeadline: new Date(Date.now() + 5 * 86400000).toISOString().split('T')[0],
            total: 480.00,
            abono: 240.00,
            status: 'detenido',
            pauseReason: 'Esperando confirmación final del cliente sobre el tono exacto de azul para el logo de la clínica.',
            notes: [
              { date: '15/10/2026, 11:20', text: 'Proyecto detenido: Se enviaron muestras de azul al cliente vía WhatsApp. Pendiente respuesta.' }
            ],
            photos: []
          }
        ];
        if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_projects', state.proyectos); } else { localStorage.setItem('martk_projects', JSON.stringify(state.proyectos)); }
      }
      renderProjectsPipeline();
      updateProjectKPIs();
    } catch (e) {
      state.proyectos = [];
    }
  }

  function saveProyectosToStorage() {
    if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_projects', state.proyectos); } else { localStorage.setItem('martk_projects', JSON.stringify(state.proyectos)); }
    updateProjectKPIs();
  }

  function renderProjectsPipeline() {
    const container = document.getElementById('projects-pipeline-container');
    if (!container) return;
    const search = document.getElementById('search-projects');
    const qStr = (search ? search.value : '').toLowerCase().trim();
    container.innerHTML = '';

    const badgeCounts = document.getElementById('sidebar-projects-count');
    const countAll = document.getElementById('count-all-projects');
    if (countAll) countAll.textContent = state.proyectos.length;
    if (badgeCounts) badgeCounts.textContent = state.proyectos.filter(p => p.status !== 'culminado').length;

    const filtered = state.proyectos.filter(p => {
      if (state.projectFilter !== 'all' && p.status !== state.projectFilter) return false;
      if (!qStr) return true;
      return (p.title || '').toLowerCase().includes(qStr) ||
             (p.clientName || '').toLowerCase().includes(qStr) ||
             (p.code || '').toLowerCase().includes(qStr);
    });

    if (filtered.length === 0) {
      container.innerHTML = `<div style="grid-column: 1 / -1; text-align:center; padding:3rem; color:#94A3B8; background:#FFFFFF; border-radius:var(--radius-lg); border:1px dashed #CBD5E1;">
        <i class="fa-solid fa-folder-open" style="font-size:2.5rem; margin-bottom:0.75rem;"></i>
        <p style="font-size:1rem; font-weight:700;">No se encontraron proyectos en este estado.</p>
      </div>`;
      return;
    }

    filtered.forEach(p => {
      const card = document.createElement('div');
      card.className = 'project-card';

      const statusLabels = {
        'presupuesto': { label: '1 · Presupuesto', cls: 'status-presupuesto' },
        'aprobado': { label: '1 · Aprobado', cls: 'status-aprobado' },
        'abono': { label: '2 · Anticipo Pendiente', cls: 'status-abono' },
        'produccion': { label: '3 · Armado Taller CNC', cls: 'status-produccion' },
        'envio': { label: '4 · Envío / Listo', cls: 'status-envio' },
        'instalacion': { label: '4 · En Sitio / Montaje', cls: 'status-instalacion' },
        'culminado': { label: '5 · Liquidado & Culminado', cls: 'status-culminado' },
        'detenido': { label: 'DETENIDO / EN PAUSA', cls: 'status-detenido' }
      };

      const st = statusLabels[p.status] || { label: p.status, cls: 'status-presupuesto' };
      const saldo = Math.max(0, (p.total || 0) - (p.abono || 0));
      const pctPagado = p.total > 0 ? Math.min(100, Math.round(((p.abono || 0) / p.total) * 100)) : 0;

      let pauseAlertHtml = '';
      if (p.status === 'detenido') {
        pauseAlertHtml = `
          <div class="project-pause-alert">
            <div class="project-pause-alert-title"><i class="fa-solid fa-circle-exclamation"></i> Proyecto en Pausa / Detenido:</div>
            <div class="project-pause-alert-text">${escapeHtml(p.pauseReason || 'Sin razón especificada. Toca "Cambiar Estado" para actualizar.')}</div>
          </div>
        `;
      }

      const thumbUrl = (p.photos && p.photos.length > 0) ? p.photos[0].url : (p.id === 2001 ? 'https://images.unsplash.com/photo-1541888946425-d0fbb186c5f7?auto=format&fit=crop&w=200&q=80' : 'https://images.unsplash.com/photo-1563245372-f21724e3856d?auto=format&fit=crop&w=200&q=80');

      card.innerHTML = `
        <div class="project-card-header">
          <div style="display:flex; align-items:center; gap:0.4rem;">
            <span class="w-2 h-2 rounded-full" style="display:inline-block; width:8px; height:8px; border-radius:50%; background:${p.status === 'detenido' ? '#DC2626' : (p.status === 'produccion' ? '#2563EB' : '#059669')};"></span>
            <span class="project-code-tag">${escapeHtml(p.code)}</span>
          </div>
          <span class="status-badge ${st.cls}">${st.label}</span>
        </div>

        <div style="display:flex; justify-content:space-between; align-items:flex-start; gap:0.75rem;">
          <div style="min-width:0; flex:1;">
            <h3 class="project-title">${escapeHtml(p.title)}</h3>
            <div class="project-client-line">
              <i class="fa-solid fa-user"></i> <strong>${escapeHtml(p.clientName || 'Cliente')}</strong>
              ${p.clientPhone ? `<a href="https://api.whatsapp.com/send?phone=${p.clientPhone.replace(/[^0-9]/g, '')}" target="_blank" style="color:#25D366; margin-left:0.25rem;"><i class="fa-brands fa-whatsapp"></i></a>` : ''}
            </div>
            ${p.address ? `<div style="font-size:0.75rem; color:#64748B; margin-top:0.2rem;"><i class="fa-solid fa-location-dot"></i> ${escapeHtml(p.address)}</div>` : ''}
          </div>
          <div class="project-thumb-box">
            <img src="${thumbUrl}" alt="Preview">
          </div>
        </div>

        ${pauseAlertHtml}

        <div style="display:flex; justify-content:space-between; font-size:0.8rem; color:#475569; background:#F8FAFC; padding:0.4rem 0.6rem; border-radius:var(--radius-sm);">
          <span><strong>Inicio:</strong> ${p.dateStart || '-'}</span>
          <span><strong>Entrega:</strong> <span style="color:#E11D48; font-weight:800;">${p.dateDeadline || '-'}</span></span>
        </div>

        <div class="project-financials">
          <div class="project-financials-row">
            <span>Anticipo pactado (50%): <strong>$${(p.abono || 0).toFixed(2)}</strong></span>
            <span>Total: <strong>$${(p.total || 0).toFixed(2)}</strong> (${pctPagado}%)</span>
          </div>
          <div class="financial-progress-track">
            <div class="financial-progress-bar" style="width:${pctPagado}%; background:${pctPagado < 50 ? '#DC2626' : (pctPagado < 100 ? '#2563EB' : '#059669')};"></div>
          </div>
          <div style="font-size:0.75rem; color:#64748B; text-align:right; margin-top:0.15rem;">
            Saldo Pendiente: <strong style="color:${saldo > 0 ? '#DC2626' : '#059669'};">$${saldo.toFixed(2)} USD</strong>
          </div>
        </div>

        ${p.status === 'abono' && saldo > 0 ? `
          <div style="display:flex; align-items:center; gap:0.5rem; background:#EFF6FF; color:#1E40AF; padding:0.5rem 0.75rem; border-radius:var(--radius-sm); font-size:0.75rem;">
            <i class="fa-solid fa-receipt"></i>
            <span>Esperando comprobante de transferencia bancaria</span>
          </div>
        ` : ''}

        <div class="project-card-actions">
          <button type="button" class="btn btn-sm btn-outline btn-p-status" data-id="${p.id}"><i class="fa-solid fa-arrows-spin"></i> Estado</button>
          <button type="button" class="btn btn-sm btn-outline btn-p-notes" data-id="${p.id}"><i class="fa-solid fa-clipboard-list"></i> Notas (${(p.notes || []).length})</button>
          <button type="button" class="btn btn-sm btn-outline btn-p-photos" data-id="${p.id}"><i class="fa-solid fa-camera"></i> Fotos (${(p.photos || []).length})</button>
          <button type="button" class="btn btn-sm btn-calendar btn-p-calendar" data-id="${p.id}"><i class="fa-solid fa-calendar-days"></i> Agendar</button>
        </div>

        ${saldo > 0 ? `
          <button type="button" class="btn btn-sm btn-stitch-primary btn-p-charge mt-1" data-id="${p.id}">
            <i class="fa-solid fa-credit-card"></i> Cobrar Saldo ($${saldo.toFixed(2)}) en POS
          </button>
        ` : ''}
      `;

      container.appendChild(card);
    });

    container.querySelectorAll('.btn-q-convert').forEach(b => {
      b.addEventListener('click', () => convertQuoteToProject(b.dataset.id));
    });
    container.querySelectorAll('.btn-q-view').forEach(b => {
      b.addEventListener('click', () => {
        const q = state.cotizaciones.find(item => item.id == b.dataset.id);
        if (q) {
          initActiveQuote(q);
          switchView('view-cotizacion-detalle');
        }
      });
    });
    container.querySelectorAll('.btn-q-edit').forEach(b => {
      b.addEventListener('click', () => {
        const q = state.cotizaciones.find(item => item.id == b.dataset.id);
        if (q) {
          initActiveQuote(q);
          switchView('view-cotizacion-detalle');
          showToast(`Cargada ${q.folio} en editor.`, 'info');
        }
      });
    });
    container.querySelectorAll('.btn-q-wa').forEach(b => {
      b.addEventListener('click', () => {
        const q = state.cotizaciones.find(item => item.id == b.dataset.id);
        if (q) shareQuoteViaWhatsapp(q);
      });
    });
    container.querySelectorAll('.btn-q-del').forEach(b => {
      b.addEventListener('click', () => {
        if (confirm('¿Eliminar esta cotización?')) {
          state.cotizaciones = state.cotizaciones.filter(item => item.id != b.dataset.id);
          saveCotizacionesToStorage();
          renderQuotesHistory();
          showToast('Cotización eliminada.', 'info');
        }
      });
    });
  }

  function initSignatureCanvas() {
    const canvas = document.getElementById('quote-signature-canvas');
    const placeholder = document.getElementById('signature-placeholder');
    const btnClear = document.getElementById('btn-clear-signature');
    if (!canvas) return;

    const ctx = canvas.getContext('2d');

    function resizeCanvas() {
      const rect = canvas.getBoundingClientRect();
      if (rect.width > 0 && rect.height > 0) {
        canvas.width = rect.width;
        canvas.height = rect.height;
        ctx.strokeStyle = '#0F172A';
        ctx.lineWidth = 2.2;
        ctx.lineCap = 'round';
        ctx.lineJoin = 'round';
      }
    }

    resizeCanvas();
    window.addEventListener('resize', resizeCanvas);

    function startDraw(e) {
      isDrawingSignature = true;
      if (placeholder) placeholder.style.display = 'none';
      const rect = canvas.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      ctx.beginPath();
      ctx.moveTo(clientX - rect.left, clientY - rect.top);
    }

    function draw(e) {
      if (!isDrawingSignature) return;
      e.preventDefault();
      const rect = canvas.getBoundingClientRect();
      const clientX = e.touches ? e.touches[0].clientX : e.clientX;
      const clientY = e.touches ? e.touches[0].clientY : e.clientY;
      ctx.lineTo(clientX - rect.left, clientY - rect.top);
      ctx.stroke();
    }

    function stopDraw() {
      if (!isDrawingSignature) return;
      isDrawingSignature = false;
      if (state.activeQuote) {
        state.activeQuote.signature = canvas.toDataURL('image/png');
      }
    }

    canvas.addEventListener('mousedown', startDraw);
    canvas.addEventListener('mousemove', draw);
    canvas.addEventListener('mouseup', stopDraw);
    canvas.addEventListener('mouseleave', stopDraw);

    canvas.addEventListener('touchstart', startDraw, { passive: false });
    canvas.addEventListener('touchmove', draw, { passive: false });
    canvas.addEventListener('touchend', stopDraw);

    if (btnClear) {
      btnClear.addEventListener('click', () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        if (placeholder) placeholder.style.display = 'flex';
        if (state.activeQuote) state.activeQuote.signature = null;
      });
    }

    signatureCanvasInited = true;
  }

  function openQuoteSheetModal(quote) {
    if (quote) initActiveQuote(quote);
    switchView('view-cotizacion-detalle');
    const modal = document.getElementById('modal-quote-sheet');
    if (!modal) return;

    // Logo oficial de empresa si existe
    const logoImg = document.getElementById('qsheet-logo-img');
    if (logoImg) {
      if (state.business.logo) {
        logoImg.src = state.business.logo;
        logoImg.style.display = 'block';
      } else {
        logoImg.style.display = 'none';
      }
    }

    const bName = document.getElementById('qsheet-biz-name');
    const bPhone = document.getElementById('qsheet-biz-phone');
    const bAddress = document.getElementById('qsheet-biz-address');
    if (bName) bName.textContent = state.business.name || 'TU NEGOCIO DE PUBLICIDAD';
    if (bPhone) bPhone.textContent = state.business.phone ? `Tel / WhatsApp: ${state.business.phone}` : '';
    if (bAddress) bAddress.textContent = state.business.address ? `Dirección: ${state.business.address}` : '';

    document.getElementById('qsheet-folio').textContent = quote.folio;
    document.getElementById('qsheet-date').textContent = `Emisión: ${quote.date}`;
    document.getElementById('qsheet-validity-text').textContent = `Vence: ${quote.validityDays || 15} días`;
    document.getElementById('qsheet-client-name').textContent = quote.clientName || 'Cliente';
    document.getElementById('qsheet-client-phone').textContent = quote.clientPhone || '-';
    document.getElementById('qsheet-title').textContent = quote.title || 'Proyecto de Publicidad';

    // Ficha de materiales incluidos en el membrete
    const materialsRow = document.getElementById('qsheet-materials-row');
    if (materialsRow) {
      materialsRow.innerHTML = `
        <span class="materials-pill"><span class="materials-dot" style="background:#F59E0B;"></span>Acrílico Espejo Dorado</span>
        <span class="materials-pill"><span class="materials-dot" style="background:#10B981;"></span>Puntera LED Neón IP67</span>
        <span class="materials-pill"><span class="materials-dot" style="background:#3B82F6;"></span>Lona Front 13oz Sellada</span>
      `;
    }

    const tbody = document.getElementById('qsheet-items-body');
    tbody.innerHTML = '';
    (quote.items || []).forEach((it, idx) => {
      const sub = (it.cant || 0) * (it.unitPrice || 0);
      const tr = document.createElement('tr');
      tr.style.borderBottom = '1px solid #E2E8F0';
      tr.innerHTML = `
        <td style="padding:0.6rem 0.8rem; font-weight:700; color:#64748B;">${idx + 1}</td>
        <td style="padding:0.6rem 0.8rem;">
          <strong style="color:#0F172A;">${escapeHtml(it.desc)}</strong>
        </td>
        <td style="padding:0.6rem 0.8rem; text-align:center; font-weight:700;">${it.cant}</td>
        <td style="padding:0.6rem 0.8rem; text-align:right;">$${(it.unitPrice || 0).toFixed(2)}</td>
        <td style="padding:0.6rem 0.8rem; text-align:right; font-weight:700; color:#0F172A;">$${sub.toFixed(2)}</td>
      `;
      tbody.appendChild(tr);
    });

    const rate = state.exchange.rate || 1;
    const totalClient = quote.totalClient || 0;
    const anticipo = totalClient * 0.50;
    const bcvVal = totalClient * rate;

    const elTotalUsd = document.getElementById('qsheet-total-usd');
    const elAnticipoUsd = document.getElementById('qsheet-anticipo-usd');
    const elTotalBcv = document.getElementById('qsheet-total-bcv');
    const elRateNote = document.getElementById('qsheet-rate-note');

    if (elTotalUsd) elTotalUsd.textContent = `$${totalClient.toFixed(2)} USD`;
    if (elAnticipoUsd) elAnticipoUsd.textContent = `$${anticipo.toFixed(2)} USD`;
    if (elTotalBcv) elTotalBcv.textContent = `Equivalente: Bs. ${bcvVal.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    if (elRateNote) elRateNote.textContent = `Tasa Oficial BCV de referencia: ${rate.toFixed(2)} Bs. / USD.`;

    // Cuentas bancarias de anticipos
    const bankArea = document.getElementById('bank-info-textarea');
    const qBankInfo = document.getElementById('qsheet-bank-info');
    if (qBankInfo) {
      qBankInfo.textContent = bankArea && bankArea.value.trim() ? bankArea.value.trim() : 'Pago Móvil: Banesco (0134) • C.I: 12.345.678 • Tel: 0414-0000000';
    }

    modal.classList.remove('hidden');

    setTimeout(() => {
      if (!signatureCanvasInited) initSignatureCanvas();
    }, 150);
  }

  function shareQuoteViaWhatsapp(quote) {
    if (!quote) return;
    const rate = state.exchange.rate || 1;
    const totalClient = quote.totalClient || 0;
    const bcvVal = totalClient * rate;
    const anticipo = totalClient * 0.50;

    let msg = `*PRESUPUESTO FORMAL: ${quote.folio}*
`;
    if (state.business.name) msg += `*${state.business.name}*
`;
    msg += `-----------------------------------
`;
    msg += `*Proyecto:* ${quote.title}
`;
    msg += `*Cliente:* ${quote.clientName}
`;
    msg += `*Fecha:* ${quote.date} (Validez: ${quote.validityDays} días)
`;
    msg += `-----------------------------------
*DESGLOSE:* 
`;

    (quote.items || []).forEach(it => {
      const sub = (it.cant || 0) * (it.unitPrice || 0);
      msg += `• *${it.cant}x* ${it.desc} -> $${sub.toFixed(2)}
`;
    });

    msg += `-----------------------------------
`;
    msg += `*TOTAL DEL PROYECTO: $${totalClient.toFixed(2)} USD*
`;
    msg += `*Anticipo 50% Requerido: $${anticipo.toFixed(2)} USD*
`;
    msg += `*Equivalente BCV:* Bs. ${bcvVal.toLocaleString('es-VE', { minimumFractionDigits: 2 })}
`;
    msg += `*Condiciones:* 50% al iniciar para adquisición de materiales y corte CNC • 50% contra entrega e instalación.

`;
    
    const bankArea = document.getElementById('bank-info-textarea');
    if (bankArea && bankArea.value.trim()) {
      msg += `*Cuentas para Pago de Anticipo:*
${bankArea.value.trim()}

`;
    }

    msg += `_Cotizado con MARKT POS & Publicraft Studio_`;

    const encoded = encodeURIComponent(msg);
    const targetPhone = (quote.clientPhone || '').replace(/[^0-9]/g, '');
    const waUrl = targetPhone ? `https://api.whatsapp.com/send?phone=${targetPhone}&text=${encoded}` : `https://api.whatsapp.com/send?text=${encoded}`;
    window.open(waUrl, '_blank');
  }

  function convertQuoteToProject(quoteId) {
    const quote = state.cotizaciones.find(q => q.id == quoteId) || state.activeQuote;
    if (!quote) return;

    const pNum = (state.proyectos.length + 1).toString().padStart(3, '0');
    const newProj = {
      id: Date.now(),
      code: `PRJ-${pNum}`,
      title: quote.title || 'Trabajo de Publicidad',
      clientName: quote.clientName || 'Cliente',
      clientPhone: quote.clientPhone || '',
      address: (quote.facadeSurvey && quote.facadeSurvey.dim) ? `Fachada: ${quote.facadeSurvey.dim}` : '',
      dateStart: new Date().toISOString().split('T')[0],
      dateDeadline: new Date(Date.now() + 7 * 86400000).toISOString().split('T')[0],
      total: quote.totalClient || 0,
      abono: 0,
      status: 'aprobado',
      pauseReason: '',
      notes: [
        { date: new Date().toLocaleString('es-ES'), text: `Proyecto creado desde cotización ${quote.folio}` }
      ],
      photos: (quote.facadeSurvey && quote.facadeSurvey.photos) || []
    };

    state.proyectos.unshift(newProj);
    saveProyectosToStorage();
    showToast(`¡Proyecto ${newProj.code} creado exitosamente!`, 'success');

    const navBtn = document.querySelector('[data-view="view-proyectos"]');
    if (navBtn) navBtn.click();
  }

  // ==========================================================================
  // MÓDULO 8: GALERÍA DE PORTAFOLIO & VISOR DE IMÁGENES
  // ==========================================================================

  function loadGaleriaFromStorage() {
    try {
      const saved = localStorage.getItem('martk_gallery');
      if (saved) {
        state.galeria = JSON.parse(saved);
      } else {
        state.galeria = [
          {
            id: 3001,
            title: 'Aviso Neón LED "Burger Gourmet" en Acrílico 3mm',
            category: 'Aviso LED',
            client: 'Burger House',
            date: '10/10/2026',
            url: 'https://images.unsplash.com/photo-1563245372-f21724e3856d?w=600&auto=format&fit=crop&q=80'
          },
          {
            id: 3002,
            title: 'Letras Corpóreas en MDF y Acrílico Espejo Dorado',
            category: 'Corpóreo',
            client: 'Boutique Elegance',
            date: '08/10/2026',
            url: 'https://images.unsplash.com/photo-1542744095-fcf48d80b0fd?w=600&auto=format&fit=crop&q=80'
          }
        ];
        if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_gallery', state.galeria); } else { localStorage.setItem('martk_gallery', JSON.stringify(state.galeria)); }
      }
      renderGallery();
    } catch (e) {
      state.galeria = [];
    }
  }

  function saveGaleriaToStorage() {
    if (window.MarktNativeStorage) { window.MarktNativeStorage.setItem('martk_gallery', state.galeria); } else { localStorage.setItem('martk_gallery', JSON.stringify(state.galeria)); }
  }

  function renderGallery() {
    const container = document.getElementById('gallery-container');
    if (!container) return;
    container.innerHTML = '';

    const filtered = state.galeria.filter(item => {
      if (state.galleryCatFilter === 'all') return true;
      return item.category === state.galleryCatFilter;
    });

    if (filtered.length === 0) {
      container.innerHTML = `<div style="grid-column: 1 / -1; text-align:center; padding:3rem; color:#94A3B8;">
        <i class="fa-solid fa-images" style="font-size:2.5rem; margin-bottom:0.75rem;"></i>
        <p>No hay fotos en esta categoría de portafolio.</p>
      </div>`;
      return;
    }

    filtered.forEach(item => {
      const card = document.createElement('div');
      card.className = 'gallery-card';
      card.innerHTML = `
        <div class="gallery-img-container">
          <span class="gallery-badge">${escapeHtml(item.category)}</span>
          <img src="${item.url}" alt="${escapeHtml(item.title)}">
        </div>
        <div class="gallery-card-info">
          <div class="gallery-card-title">${escapeHtml(item.title)}</div>
          <div class="gallery-card-client"><i class="fa-solid fa-user"></i> ${escapeHtml(item.client || 'Cliente')} • <small>${item.date || ''}</small></div>
          <div style="margin-top:auto; display:flex; justify-content:space-between; align-items:center; padding-top:0.5rem; border-top:1px solid #F1F5F9;">
            <button class="btn btn-sm btn-outline btn-gal-view" data-url="${item.url}" data-title="${escapeHtml(item.title)}"><i class="fa-solid fa-eye"></i> Ver Grande</button>
            <button class="btn btn-sm btn-danger-outline btn-gal-del" data-id="${item.id}"><i class="fa-solid fa-trash"></i></button>
          </div>
        </div>
      `;
      container.appendChild(card);
    });

    container.querySelectorAll('.btn-gal-view').forEach(b => {
      b.addEventListener('click', () => openImageViewerModal(b.dataset.url, b.dataset.title));
    });
    container.querySelectorAll('.btn-gal-del').forEach(b => {
      b.addEventListener('click', () => {
        if (confirm('¿Eliminar esta foto del portafolio?')) {
          state.galeria = state.galeria.filter(g => g.id != b.dataset.id);
          saveGaleriaToStorage();
          renderGallery();
          showToast('Foto eliminada.', 'info');
        }
      });
    });
  }

  function openImageViewerModal(imgSrc, title) {
    const modal = document.getElementById('modal-image-viewer');
    const img = document.getElementById('image-viewer-img');
    const titleEl = document.getElementById('image-viewer-title');
    const btnDownload = document.getElementById('btn-download-viewer-img');
    if (!modal || !img) return;

    img.src = imgSrc;
    if (titleEl) titleEl.textContent = title || 'Visualizador de Imagen';
    if (btnDownload) {
      btnDownload.href = imgSrc;
      btnDownload.download = `MARKT_${(title || 'Foto').replace(/[^a-zA-Z0-9]/g, '_')}.png`;
    }

    modal.classList.remove('hidden');
  }

  // ==========================================================================
  // CONFIGURACIÓN DE EVENT LISTENERS DE LOS NUEVOS MÓDULOS
  // ==========================================================================
  function setupNewModulesEventListeners() {

    // POS Real-time Catalog Search
    const inputStitchPosSearch = document.getElementById('stitch-pos-search');
    if (inputStitchPosSearch) {
      inputStitchPosSearch.addEventListener('input', () => {
        renderPosQuickCatalog();
      });
    }

    // POS Category Filter Buttons
    document.querySelectorAll('.pos-cat-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.pos-cat-btn').forEach(b => {
          b.classList.remove('bg-primary', 'text-on-primary');
          b.classList.add('bg-surface-container-lowest', 'text-on-surface-variant');
        });
        btn.classList.remove('bg-surface-container-lowest', 'text-on-surface-variant');
        btn.classList.add('bg-primary', 'text-on-primary');

        renderPosQuickCatalog();
      });
    });

    // Inline Project Form toggling (No modal)
    const btnShowAddProj = document.getElementById('btn-show-add-project');
    const projectFormBox = document.getElementById('project-form-box');
    const btnCancelProjForm = document.getElementById('btn-cancel-project-form');
    if (btnShowAddProj && projectFormBox) {
      btnShowAddProj.addEventListener('click', () => {
        projectFormBox.classList.toggle('hidden');
        if (!projectFormBox.classList.contains('hidden')) {
          projectFormBox.scrollIntoView({ behavior: 'smooth' });
        }
      });
    }
    if (btnCancelProjForm && projectFormBox) {
      btnCancelProjForm.addEventListener('click', () => {
        projectFormBox.classList.add('hidden');
      });
    }

    // Stitch POS Quick Add Buttons
    document.querySelectorAll('.btn-stitch-quick-add').forEach(btn => {
      btn.addEventListener('click', () => {
        const desc = btn.getAttribute('data-desc') || 'Producto';
        const sub = btn.getAttribute('data-sub') || '';
        const price = parseFloat(btn.getAttribute('data-price')) || 0;
        
        const existing = state.items.find(i => i.desc === desc);
        if (existing) {
          existing.cant = (parseFloat(existing.cant) || 0) + 1;
        } else {
          state.items.push({
            id: Date.now().toString(),
            cant: 1,
            desc: desc,
            subtext: sub,
            taxRate: 16,
            unitPrice: price
          });
        }
        renderItemsList();
        updateCalculationsAndPreview();
        showToast(`Añadido al ticket: ${desc}`, 'success');
      });
    });

    // Stitch POS Charge Button
    const btnStitchCharge = document.getElementById('btn-stitch-charge');
    if (btnStitchCharge) {
      btnStitchCharge.addEventListener('click', () => {
        if (!state.items || state.items.length === 0) {
          showToast('El ticket está vacío.', 'info');
          return;
        }
        saveCurrentDocumentToHistory();
        showToast('Venta cobrada y registrada en historial.', 'success');
      });
    }

    // Stitch POS Save as Quote Button
    const btnStitchSaveQuote = document.getElementById('btn-stitch-save-quote');
    if (btnStitchSaveQuote) {
      btnStitchSaveQuote.addEventListener('click', () => {
        if (!state.items || state.items.length === 0) {
          showToast('Añade al menos un producto o partida al ticket para cotizar.', 'info');
          return;
        }
        const newFolio = `COT-${new Date().getFullYear()}-${String(state.cotizaciones.length + 1).padStart(3, '0')}`;
        const newQ = {
          id: Date.now(),
          folio: newFolio,
          title: state.items.map(i => i.desc).filter(Boolean).slice(0, 2).join(' + ') || 'Presupuesto Comercial',
          clientName: state.client.name || 'Cliente Mostrador',
          clientPhone: state.client.phone || '',
          date: new Date().toISOString().split('T')[0],
          validityDays: 15,
          status: 'Borrador',
          items: state.items.map(i => ({
            type: 'material',
            desc: i.desc || 'Partida',
            cant: parseFloat(i.cant) || 1,
            unitCost: (parseFloat(i.unitPrice) || 0) * 0.6,
            unitPrice: parseFloat(i.unitPrice) || 0
          })),
          subtotal: state.totals.subtotal,
          totalClient: state.totals.grandTotal,
          anticipoUsd: state.totals.grandTotal * 0.5,
          notes: 'Presupuesto formal emitido desde POS.'
        };
        state.cotizaciones.unshift(newQ);
        saveCotizacionesToStorage();
        renderQuotesHistory();
        initActiveQuote(newQ);
        switchView('view-cotizacion-detalle');
        showToast(`Cotización ${newFolio} generada. Abierta en vista formal.`, 'success');
      });
    }

    // Stitch Proyectos Stepper Filter
    document.querySelectorAll('#stage-stepper .phase-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        const stage = chip.getAttribute('data-stage');
        document.querySelectorAll('#stage-stepper .phase-chip').forEach(c => {
          c.classList.remove('bg-secondary-container', 'text-on-secondary-container', 'border-secondary');
          c.classList.add('bg-surface-container-lowest', 'text-on-surface');
          const numBadge = c.querySelector('div:first-child');
          if (numBadge) {
            numBadge.className = 'w-6 h-6 rounded-full bg-surface-container flex items-center justify-center font-label-numeric text-label-numeric font-bold text-on-surface';
          }
        });

        chip.classList.remove('bg-surface-container-lowest', 'text-on-surface');
        chip.classList.add('bg-secondary-container', 'text-on-secondary-container', 'border-secondary');
        const activeBadge = chip.querySelector('div:first-child');
        if (activeBadge) {
          activeBadge.className = 'w-6 h-6 rounded-full bg-surface-container-lowest flex items-center justify-center font-label-numeric text-label-numeric text-secondary font-bold';
        }

        const stageMap = {
          '1': 'presupuesto',
          '2': 'abono',
          '3': 'produccion',
          '4': 'instalacion',
          '5': 'culminado'
        };
        state.projectFilter = stageMap[stage] || 'all';
        renderProjectsPipeline();
      });
    });

    const btnResetProjectFilter = document.getElementById('reset-filter-btn');
    if (btnResetProjectFilter) {
      btnResetProjectFilter.addEventListener('click', () => {
        state.projectFilter = 'all';
        document.querySelectorAll('#stage-stepper .phase-chip').forEach(c => {
          c.classList.remove('bg-secondary-container', 'text-on-secondary-container', 'border-secondary');
          c.classList.add('bg-surface-container-lowest', 'text-on-surface');
        });
        renderProjectsPipeline();
      });
    }

    // Stitch Cotizaciones Filter Chips
    document.querySelectorAll('#quote-status-filter-group .quote-filter-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#quote-status-filter-group .quote-filter-chip').forEach(c => {
          c.classList.remove('bg-primary', 'text-on-primary');
          c.classList.add('bg-surface-container-lowest', 'text-on-surface-variant');
        });
        chip.classList.remove('bg-surface-container-lowest', 'text-on-surface-variant');
        chip.classList.add('bg-primary', 'text-on-primary');

        const st = chip.getAttribute('data-status');
        state.quoteStatusFilter = (st === 'todas') ? 'all' : (st === 'aprobada' ? 'Aprobado' : (st === 'enviada' ? 'Enviada' : 'Borrador'));
        renderQuotesHistory();
      });
    });

    // Copy CLABE button
    const btnCopyClabe = document.getElementById('btn-copy-clabe');
    if (btnCopyClabe) {
      btnCopyClabe.addEventListener('click', () => {
        const text = document.getElementById('clabe-code-text')?.textContent || '0134 • V-24190824 • 04128421990';
        if (navigator.clipboard) {
          navigator.clipboard.writeText(text).then(() => {
            showToast('Datos bancarios copiados al portapapeles.', 'success');
          });
        } else {
          showToast('Copiado: ' + text, 'info');
        }
      });
    }

    // Google Calendar button
    const btnGCal = document.getElementById('btn-quote-gcalendar');
    if (btnGCal) {
      btnGCal.addEventListener('click', () => {
        const title = encodeURIComponent('Montaje Aviso Corpóreo - PubliCraft');
        const details = encodeURIComponent('Cuadrilla: Técnico CNC + 2 Montajistas. Proyecto: Boutique Velvet & Co.');
        const location = encodeURIComponent('Boutique Velvet & Co.');
        const url = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${title}&details=${details}&location=${location}`;
        window.open(url, '_blank');
      });
    }

    // Close Quote Sheet modal button
    const btnCloseQuoteSheet = document.getElementById('btn-close-quote-sheet');
    if (btnCloseQuoteSheet) {
      btnCloseQuoteSheet.addEventListener('click', () => {
        document.getElementById('modal-quote-sheet')?.classList.add('hidden');
      });
    }

    // 1. Cotizaciones
    const btnNewQ = document.getElementById('btn-new-quote');
    if (btnNewQ) btnNewQ.addEventListener('click', () => initActiveQuote());

    const toggleProfit = document.getElementById('quote-toggle-profit-mode');
    if (toggleProfit) {
      toggleProfit.addEventListener('change', e => {
        state.quoteProfitMode = e.target.checked;
        applyQuoteProfitModeVisibility();
      });
    }

    const btnAddRow = document.getElementById('btn-add-quote-row');
    if (btnAddRow) {
      btnAddRow.addEventListener('click', () => {
        if (!state.activeQuote) initActiveQuote();
        state.activeQuote.items.push({
          type: 'material',
          desc: '',
          cant: 1,
          unitCost: 0,
          unitPrice: 0
        });
        renderQuoteItemsTable();
      });
    }

    // Plantillas rápidas de costos
    document.querySelectorAll('.btn-quick-cost').forEach(b => {
      b.addEventListener('click', () => {
        if (!state.activeQuote) initActiveQuote();
        state.activeQuote.items.push({
          type: b.dataset.type || 'material',
          desc: b.dataset.desc || 'Ítem',
          cant: 1,
          unitCost: parseFloat(b.dataset.cost) || 0,
          unitPrice: parseFloat(b.dataset.price) || 0
        });
        renderQuoteItemsTable();
        recalcQuoteTotals();
        showToast(`Agregado: ${b.dataset.desc}`, 'success');
      });
    });

    const btnSaveQ = document.getElementById('btn-save-quote');
    if (btnSaveQ) btnSaveQ.addEventListener('click', saveCurrentQuote);

    const btnPreviewQ = document.getElementById('btn-preview-quote-client');
    if (btnPreviewQ) {
      btnPreviewQ.addEventListener('click', () => {
        if (state.activeQuote) openQuoteSheetModal(state.activeQuote);
      });
    }

    const btnQWa = document.getElementById('btn-quote-whatsapp');
    if (btnQWa) {
      btnQWa.addEventListener('click', () => {
        if (state.activeQuote) shareQuoteViaWhatsapp(state.activeQuote);
      });
    }

    const btnConvertQ = document.getElementById('btn-convert-quote-to-project');
    if (btnConvertQ) {
      btnConvertQ.addEventListener('click', () => {
        if (state.activeQuote) convertQuoteToProject(state.activeQuote.id);
      });
    }

    const searchQ = document.getElementById('search-quotes');
    if (searchQ) searchQ.addEventListener('input', renderQuotesHistory);

    // Botones modal quote sheet
    
    // Listeners Stitch: Filtros de estado en Cotizaciones
    document.querySelectorAll('.quote-filter-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('.quote-filter-chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.quoteStatusFilter = chip.dataset.status;
        renderQuotesHistory();
      });
    });

    // Listeners Stitch: Cargar Archivo Vectorial
    const btnAddVector = document.getElementById('btn-add-vector-file');
    if (btnAddVector) {
      btnAddVector.addEventListener('click', () => {
        const name = prompt('Nombre del archivo vectorial (ej: logo_letras_3d.dxf):', 'corte_letras_aviso.dxf');
        if (!name) return;
        const machine = prompt('Material / Máquina asignada:', 'Router CNC 12mm MDF + Acrílico');
        const ext = name.split('.').pop().toLowerCase();
        if (!state.activeQuote.vectorFiles) state.activeQuote.vectorFiles = [];
        state.activeQuote.vectorFiles.push({
          id: 'vec-' + Date.now(),
          name,
          type: ext,
          size: '3.5 MB',
          machine: machine || 'Router CNC',
          validStatus: 'Vector Validado 1:1'
        });
        renderVectorFilesList();
        showToast('Archivo vectorial registrado.', 'success');
      });
    }

    // Listeners Stitch: Agregar Foto Levantamiento Fachada
    const btnAddSurvey = document.getElementById('btn-add-facade-survey');
    if (btnAddSurvey) {
      btnAddSurvey.addEventListener('click', () => {
        const cota = prompt('Cota / Medida en fachada (ej: 400 x 150 cm):', '380 x 140 cm');
        if (!cota) return;
        if (!state.activeQuote.facadeSurvey) state.activeQuote.facadeSurvey = { photos: [] };
        if (!state.activeQuote.facadeSurvey.photos) state.activeQuote.facadeSurvey.photos = [];
        state.activeQuote.facadeSurvey.photos.push({
          title: 'Levantamiento Fachada ' + (state.activeQuote.facadeSurvey.photos.length + 1),
          cota: cota,
          note: 'Anclajes y punto 220V verificado',
          url: 'https://images.unsplash.com/photo-1541888946425-d0fbb186c5f7?auto=format&fit=crop&w=600&q=80'
        });
        renderFacadeSurveyGrid();
        showToast('Foto de levantamiento registrada.', 'success');
      });
    }

    // Listener Stitch: Agendar Cotización en Google Calendar
    const btnQuoteGCal = document.getElementById('btn-quote-gcalendar');
    if (btnQuoteGCal) {
      btnQuoteGCal.addEventListener('click', () => {
        if (!state.activeQuote) return;
        const q = state.activeQuote;
        const title = encodeURIComponent(`Instalación y Montaje: ${q.title || 'Aviso Publicitario'}`);
        const details = encodeURIComponent(`Cliente: ${q.clientName}
Teléfono: ${q.clientPhone}
Total: ${q.totalClient} USD
Anticipo 50%: ${(q.totalClient * 0.5).toFixed(2)} USD
Cuadrilla: Técnico CNC + 2 Montajistas

Organizado con MARKT POS`);
        const startDateStr = q.date || new Date().toISOString().split('T')[0];
        const cleanDate = startDateStr.replace(/-/g, '');
        const dates = `${cleanDate}T140000Z/${cleanDate}T170000Z`;
        const gcalUrl = `https://calendar.google.com/calendar/render?action=TEMPLATE&text=${title}&details=${details}&dates=${dates}`;
        window.open(gcalUrl, '_blank');
      });
    }

    // Listener Stitch: Stepper horizontal de etapas de proyecto
    document.querySelectorAll('.stage-step-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('.stage-step-chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.projectFilter = chip.dataset.filter;
        renderProjectsPipeline();
      });
    });

    // Listener Stitch: Copiar datos bancarios al portapapeles
    document.querySelectorAll('.btn-copy-bank').forEach(btn => {
      btn.addEventListener('click', () => {
        const targetId = btn.dataset.target;
        const targetEl = document.getElementById(targetId);
        if (targetEl) {
          const text = targetEl.textContent.trim();
          if (navigator.clipboard) {
            navigator.clipboard.writeText(text).then(() => {
              showToast('Datos bancarios copiados al portapapeles.', 'success');
            });
          } else {
            showToast(text, 'info');
          }
        }
      });
    });

    const btnCloseQSheet = document.getElementById('btn-close-quote-sheet');
    if (btnCloseQSheet) {
      btnCloseQSheet.addEventListener('click', () => {
        document.getElementById('modal-quote-sheet').classList.add('hidden');
      });
    }

    const btnDownloadQImg = document.getElementById('btn-download-quote-img');
    if (btnDownloadQImg) {
      btnDownloadQImg.addEventListener('click', () => {
        const target = document.getElementById('quote-printable-card');
        if (!target || typeof html2canvas === 'undefined') return;
        showToast('Generando imagen de presupuesto...', 'info');
        html2canvas(target, { scale: 2.2, backgroundColor: '#FFFFFF' }).then(canvas => {
          const imgUrl = canvas.toDataURL('image/png');
          const folio = document.getElementById('qsheet-folio').textContent;
          openImageViewerModal(imgUrl, `Presupuesto_${folio}`);
          const a = document.createElement('a');
          a.href = imgUrl;
          a.download = `Presupuesto_${folio}.png`;
          a.click();
        });
      });
    }

    const btnPrintQSheet = document.getElementById('btn-print-quote-sheet');
    if (btnPrintQSheet) btnPrintQSheet.addEventListener('click', () => window.print());

    const btnShareQWaModal = document.getElementById('btn-share-quote-sheet-wa');
    if (btnShareQWaModal) {
      btnShareQWaModal.addEventListener('click', () => {
        if (state.activeQuote) shareQuoteViaWhatsapp(state.activeQuote);
      });
    }

    // 2. Proyectos
    const filterChips = document.querySelectorAll('.projects-filter-bar .filter-chip');
    filterChips.forEach(chip => {
      chip.addEventListener('click', () => {
        filterChips.forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.projectFilter = chip.dataset.filter;
        renderProjectsPipeline();
      });
    });

    const searchP = document.getElementById('search-projects');
    if (searchP) searchP.addEventListener('input', renderProjectsPipeline);

    const btnSavePStatus = document.getElementById('btn-save-project-status');
    if (btnSavePStatus) btnSavePStatus.addEventListener('click', saveProjectStatus);

    const btnClosePStatus = document.getElementById('btn-close-project-status');
    const btnCancelPStatus = document.getElementById('btn-cancel-project-status');
    if (btnClosePStatus) btnClosePStatus.addEventListener('click', () => document.getElementById('modal-project-status').classList.add('hidden'));
    if (btnCancelPStatus) btnCancelPStatus.addEventListener('click', () => document.getElementById('modal-project-status').classList.add('hidden'));

    // Formulario Nuevo Proyecto
    const btnShowAddP = document.getElementById('btn-show-add-project');
    const modalPForm = document.getElementById('modal-project-form');
    if (btnShowAddP && modalPForm) {
      btnShowAddP.addEventListener('click', () => {
        document.getElementById('p-form-title').value = '';
        document.getElementById('p-form-client-name').value = '';
        document.getElementById('p-form-client-phone').value = '';
        document.getElementById('p-form-date-start').value = new Date().toISOString().split('T')[0];
        document.getElementById('p-form-date-deadline').value = new Date(Date.now() + 5 * 86400000).toISOString().split('T')[0];
        document.getElementById('p-form-total').value = '';
        document.getElementById('p-form-abono').value = '0.00';
        document.getElementById('p-form-address').value = '';
        modalPForm.classList.remove('hidden');
      });
    }

    const btnClosePForm = document.getElementById('btn-close-project-form');
    const btnCancelPForm = document.getElementById('btn-cancel-project-form');
    if (btnClosePForm) btnClosePForm.addEventListener('click', () => modalPForm.classList.add('hidden'));
    if (btnCancelPForm) btnCancelPForm.addEventListener('click', () => modalPForm.classList.add('hidden'));

    const btnSavePForm = document.getElementById('btn-save-project-form');
    if (btnSavePForm) {
      btnSavePForm.addEventListener('click', () => {
        const title = cleanInputText(document.getElementById('p-form-title').value);
        const clientName = cleanInputText(document.getElementById('p-form-client-name').value);
        const clientPhone = cleanPhoneInput(document.getElementById('p-form-client-phone').value);
        const dateStart = document.getElementById('p-form-date-start').value;
        const dateDeadline = document.getElementById('p-form-date-deadline').value;
        const total = parseFloat(document.getElementById('p-form-total').value) || 0;
        const abono = parseFloat(document.getElementById('p-form-abono').value) || 0;
        const address = cleanInputText(document.getElementById('p-form-address').value);
        const status = document.getElementById('p-form-initial-status').value;

        if (!title || !clientName) {
          showToast('Completa el título y nombre del cliente.', 'info');
          return;
        }

        const pNum = (state.proyectos.length + 1).toString().padStart(3, '0');
        const proj = {
          id: Date.now(),
          code: `PRJ-${pNum}`,
          title,
          clientName,
          clientPhone,
          dateStart: dateStart || new Date().toISOString().split('T')[0],
          dateDeadline: dateDeadline || new Date().toISOString().split('T')[0],
          total,
          abono,
          address,
          status,
          pauseReason: '',
          notes: [{ date: new Date().toLocaleString('es-ES'), text: 'Proyecto creado manualmente.' }],
          photos: []
        };

        state.proyectos.unshift(proj);
        saveProyectosToStorage();
        renderProjectsPipeline();
        modalPForm.classList.add('hidden');
        showToast(`Proyecto ${proj.code} creado exitosamente.`, 'success');
      });
    }

    // Modal Notas
    const btnClosePNotes = document.getElementById('btn-close-project-notes');
    if (btnClosePNotes) btnClosePNotes.addEventListener('click', () => document.getElementById('modal-project-notes').classList.add('hidden'));
    const btnAddPNote = document.getElementById('btn-add-project-note');
    if (btnAddPNote) btnAddPNote.addEventListener('click', addProjectNote);

    // Modal Fotos Proyecto
    const btnClosePPhotos = document.getElementById('btn-close-project-photos');
    if (btnClosePPhotos) btnClosePPhotos.addEventListener('click', () => document.getElementById('modal-project-photos').classList.add('hidden'));

    const inputUploadPPhoto = document.getElementById('input-upload-project-photo');
    if (inputUploadPPhoto) {
      inputUploadPPhoto.addEventListener('change', e => {
        const file = e.target.files[0];
        if (!file) return;
        const projId = document.getElementById('photos-modal-project-id').value;
        const p = state.proyectos.find(item => item.id == projId);
        if (!p) return;

        showToast('Comprimiendo y guardando foto del proyecto...', 'info');
        compressImageFile(file, 900, 900, 0.75, function(dataUrl) {
          if (!p.photos) p.photos = [];
          p.photos.push({
            date: new Date().toLocaleString('es-ES'),
            url: dataUrl
          });
          saveProyectosToStorage();
          renderProjectPhotosGrid(p);
          renderProjectsPipeline();
          showToast('Foto agregada al proyecto exitosamente.', 'success');
        });
      });
    }

    // 3. Galería de Portafolio
    const btnShowUploadGal = document.getElementById('btn-show-upload-gallery');
    const modalGalUpload = document.getElementById('modal-gallery-upload');
    if (btnShowUploadGal && modalGalUpload) {
      btnShowUploadGal.addEventListener('click', () => {
        document.getElementById('gal-input-title').value = '';
        document.getElementById('gal-input-client').value = '';
        document.getElementById('gal-preview-box').style.display = 'none';
        modalGalUpload.classList.remove('hidden');
      });
    }

    const btnCloseGalUpload = document.getElementById('btn-close-gallery-upload');
    const btnCancelGalUpload = document.getElementById('btn-cancel-gallery-photo');
    if (btnCloseGalUpload) btnCloseGalUpload.addEventListener('click', () => modalGalUpload.classList.add('hidden'));
    if (btnCancelGalUpload) btnCancelGalUpload.addEventListener('click', () => modalGalUpload.classList.add('hidden'));

    let tempGalPhotoUrl = '';
    const galFileInput = document.getElementById('gal-input-file');
    if (galFileInput) {
      galFileInput.addEventListener('change', e => {
        const file = e.target.files[0];
        if (!file) return;
        compressImageFile(file, 1000, 1000, 0.8, function(dataUrl) {
          tempGalPhotoUrl = dataUrl;
          document.getElementById('gal-preview-img').src = dataUrl;
          document.getElementById('gal-preview-box').style.display = 'block';
        });
      });
    }

    const btnSaveGalPhoto = document.getElementById('btn-save-gallery-photo');
    if (btnSaveGalPhoto) {
      btnSaveGalPhoto.addEventListener('click', () => {
        const title = cleanInputText(document.getElementById('gal-input-title').value);
        const category = document.getElementById('gal-select-cat').value;
        const client = cleanInputText(document.getElementById('gal-input-client').value);

        if (!title || !tempGalPhotoUrl) {
          showToast('Por favor escribe un título y selecciona una imagen.', 'info');
          return;
        }

        const newGalItem = {
          id: Date.now(),
          title,
          category,
          client: client || 'Cliente',
          date: new Date().toLocaleDateString('es-ES'),
          url: tempGalPhotoUrl
        };

        state.galeria.unshift(newGalItem);
        saveGaleriaToStorage();
        renderGallery();
        tempGalPhotoUrl = '';
        modalGalUpload.classList.add('hidden');
        showToast('Foto publicada en el portafolio exitosamente.', 'success');
      });
    }

    // Filtros de categoría de galería
    document.querySelectorAll('#view-galeria .filter-chip').forEach(chip => {
      chip.addEventListener('click', () => {
        document.querySelectorAll('#view-galeria .filter-chip').forEach(c => c.classList.remove('active'));
        chip.classList.add('active');
        state.galleryCatFilter = chip.dataset.cat;
        renderGallery();
      });
    });

    // 4. Visor de Imagen Full
    const btnCloseViewer = document.getElementById('btn-close-image-viewer');
    const btnCloseViewerAlt = document.getElementById('btn-close-viewer-alt');
    if (btnCloseViewer) btnCloseViewer.addEventListener('click', () => document.getElementById('modal-image-viewer').classList.add('hidden'));
    if (btnCloseViewerAlt) btnCloseViewerAlt.addEventListener('click', () => document.getElementById('modal-image-viewer').classList.add('hidden'));
  }

  function resetToFactoryDefaults() {
    if (confirm(' ¿Estás seguro de restablecer toda la aplicación a los valores iniciales? Se borrarán los productos, clientes, historial y configuración guardada localmente.')) {
      localStorage.clear();
      showToast('Restableciendo aplicación...', 'info');
      setTimeout(() => location.reload(), 600);
    }
  }

  // Launch App
  init();
});


  // ==========================================================================
  // HELPER: MAP PAYMENT FORMS
  // ==========================================================================
  function mapPaymentFormToCajaMethod(forma) {
    const f = (forma || '').toLowerCase();
    if (f.includes('dólar') || f.includes('dolar') || f.includes('usd') || f.includes('efectivo $')) return 'efectivo_usd';
    if (f.includes('móvil') || f.includes('movil')) return 'pago_movil';
    if (f.includes('transferencia')) return 'transferencia';
    if (f.includes('punto') || f.includes('tarjeta') || f.includes('débito') || f.includes('debito')) return 'punto_venta';
    if (f.includes('zelle')) return 'zelle';
    return 'efectivo_bs';
  }

  function getMethodLabel(method) {
    switch (method) {
      case 'efectivo_usd': return 'Efectivo ($ USD)';
      case 'efectivo_bs': return 'Efectivo (Bs.)';
      case 'pago_movil': return 'Pago Móvil (Bs.)';
      case 'transferencia': return 'Transferencia';
      case 'punto_venta': return 'Punto de Venta';
      case 'zelle': return 'Zelle (USD)';
      default: return method || 'General';
    }
  }

  // ==========================================================================
  // MÓDULO: LIBRO DE CAJA & MOVIMIENTOS ILIMITADOS (FASE 2)
  // ==========================================================================
  const cajaCategories = {
    income: [
      'Venta Directa POS',
      'Cobro a Cliente / Abono Factura',
      'Abono / Anticipo de Inicial',
      'Aporte de Capital',
      'Otro Ingreso'
    ],
    expense: [
      'Pago a Proveedor',
      'Compra de Mercancía / Insumos',
      'Nómina / Comisiones a Vendedores',
      'Servicios Básicos (Luz, Agua, Internet)',
      'Alquiler / Arrendamiento',
      'Flete / Transporte / Encomienda',
      'Mantenimiento / Reparaciones',
      'Publicidad / Marketing',
      'Impuestos / Tasas Municipales',
      'Otro Egreso Operativo'
    ]
  };

  function loadCashMovementsFromStorage() {
    if (window.MarktNativeStorage) {
      window.MarktNativeStorage.load('cash_movements.json').then(data => {
        if (data && Array.isArray(data)) state.cashMovements = data;
      });
    } else {
      const saved = localStorage.getItem('markt_cash_movements');
      if (saved) {
        try { state.cashMovements = JSON.parse(saved); } catch (e) { state.cashMovements = []; }
      }
    }
  }

  function saveCashMovementsToStorage() {
    if (window.MarktNativeStorage) {
      window.MarktNativeStorage.save('cash_movements.json', state.cashMovements);
    }
    localStorage.setItem('markt_cash_movements', JSON.stringify(state.cashMovements));
  }

  function filterCashMovementsByPeriod(list, period) {
    const now = new Date();
    return list.filter(m => {
      if (!m.date) return true;
      const d = new Date(m.date);
      if (isNaN(d.getTime())) return true;
      if (period === 'today') {
        return d.toDateString() === now.toDateString();
      } else if (period === 'week') {
        const diffDays = (now - d) / (1000 * 60 * 60 * 24);
        return diffDays >= 0 && diffDays <= 7;
      } else if (period === 'month') {
        return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
      }
      return true; // 'all'
    });
  }

  function renderCajaView() {
    renderCajaSummary();
    renderCajaTable();
    updateCajaCategoryDropdown('income');
  }

  function renderCajaSummary() {
    const period = state.cajaPeriodFilter || 'month';
    const filtered = filterCashMovementsByPeriod(state.cashMovements, period);

    let incUsd = 0;
    let incBs = 0;
    let expUsd = 0;
    let expBs = 0;

    const rate = state.exchange.rate || 1;
    const methodTotals = {
      efectivo_usd: 0,
      efectivo_bs: 0,
      pago_movil: 0,
      transferencia: 0,
      punto_venta: 0,
      zelle: 0
    };

    filtered.forEach(m => {
      const usd = Number(m.amountUsd) || 0;
      const bs = Number(m.amountBs) || (usd * rate);
      const isInc = m.type === 'income';

      if (isInc) {
        incUsd += usd;
        incBs += bs;
        if (methodTotals[m.method] !== undefined) methodTotals[m.method] += usd;
      } else {
        expUsd += usd;
        expBs += bs;
        if (methodTotals[m.method] !== undefined) methodTotals[m.method] -= usd;
      }
    });

    const netUsd = incUsd - expUsd;
    const netBs = incBs - expBs;

    const elNetUsd = document.getElementById('caja-net-usd');
    const elNetBs = document.getElementById('caja-net-bs');
    const elIncUsd = document.getElementById('caja-income-usd');
    const elIncBs = document.getElementById('caja-income-bs');
    const elExpUsd = document.getElementById('caja-expense-usd');
    const elExpBs = document.getElementById('caja-expense-bs');

    if (elNetUsd) {
      elNetUsd.textContent = `${netUsd >= 0 ? '$' : '-$'}${Math.abs(netUsd).toFixed(2)}`;
      elNetUsd.className = `font-mono text-2xl font-extrabold leading-tight ${netUsd >= 0 ? 'text-secondary' : 'text-rose-600 dark:text-rose-400'}`;
    }
    if (elNetBs) elNetBs.textContent = `${netBs >= 0 ? '' : '-'}${Math.abs(netBs).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.`;
    if (elIncUsd) elIncUsd.textContent = `+$${incUsd.toFixed(2)}`;
    if (elIncBs) elIncBs.textContent = `+${incBs.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.`;
    if (elExpUsd) elExpUsd.textContent = `-$${expUsd.toFixed(2)}`;
    if (elExpBs) elExpBs.textContent = `-${expBs.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.`;

    // Metodos grid
    const metodosGrid = document.getElementById('caja-metodos-grid');
    if (metodosGrid) {
      metodosGrid.innerHTML = '';
      const methodKeys = [
        { key: 'efectivo_usd', label: 'Efectivo $', isUsd: true },
        { key: 'efectivo_bs', label: 'Efectivo Bs.', isUsd: false },
        { key: 'pago_movil', label: 'Pago Móvil', isUsd: false },
        { key: 'transferencia', label: 'Transferencia', isUsd: false },
        { key: 'punto_venta', label: 'Punto/Tarjeta', isUsd: false },
        { key: 'zelle', label: 'Zelle', isUsd: true }
      ];

      methodKeys.forEach(mk => {
        const val = methodTotals[mk.key] || 0;
        const col = document.createElement('div');
        col.className = 'p-2 rounded-xl bg-surface-container-lowest border border-surface-container text-center';
        col.innerHTML = `
          <div class="text-[10px] text-on-surface-variant font-bold truncate">${mk.label}</div>
          <div class="font-mono text-xs font-extrabold mt-0.5 ${val >= 0 ? 'text-on-surface' : 'text-rose-600 dark:text-rose-400'}">
            ${mk.isUsd ? '$' + val.toFixed(2) : (val * rate).toLocaleString('es-VE', { maximumFractionDigits: 0 }) + ' Bs.'}
          </div>
        `;
        metodosGrid.appendChild(col);
      });
    }
  }

  function renderCajaTable() {
    const tbody = document.getElementById('caja-table-body');
    const emptyState = document.getElementById('caja-empty-state');
    const countBadge = document.getElementById('caja-count-badge');
    const search = document.getElementById('search-caja');
    const q = (search ? search.value : '').toLowerCase().trim();

    if (!tbody) return;
    tbody.innerHTML = '';

    const period = state.cajaPeriodFilter || 'month';
    const typeFilter = state.cajaTypeFilter || 'all';

    let list = filterCashMovementsByPeriod(state.cashMovements, period);

    if (typeFilter !== 'all') {
      list = list.filter(m => m.type === typeFilter);
    }

    if (q) {
      list = list.filter(m =>
        (m.concept || '').toLowerCase().includes(q) ||
        (m.category || '').toLowerCase().includes(q) ||
        (m.thirdParty || '').toLowerCase().includes(q) ||
        (m.reference || '').toLowerCase().includes(q)
      );
    }

    if (countBadge) countBadge.textContent = `${list.length} registros`;

    if (list.length === 0) {
      if (emptyState) emptyState.classList.remove('hidden');
      return;
    }
    if (emptyState) emptyState.classList.add('hidden');

    const rate = state.exchange.rate || 1;

    list.forEach(m => {
      const isInc = m.type === 'income';
      const usd = Number(m.amountUsd) || 0;
      const bs = Number(m.amountBs) || (usd * rate);
      const dStr = m.date ? new Date(m.date).toLocaleString('es-VE', { month: 'short', day: '2-digit', hour: '2-digit', minute: '2-digit', hour12: true }) : '-';

      const tr = document.createElement('tr');
      tr.className = 'hover:bg-surface-container/30 transition-colors';
      tr.innerHTML = `
        <td class="py-2.5 px-3 text-on-surface-variant font-mono text-[11px] whitespace-nowrap">${dStr}</td>
        <td class="py-2.5 px-3">
          <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold ${isInc ? 'bg-emerald-500/10 text-emerald-600 dark:text-emerald-400' : 'bg-rose-500/10 text-rose-600 dark:text-rose-400'}">
            <span class="material-symbols-outlined text-[13px]">${isInc ? 'arrow_downward' : 'arrow_upward'}</span>
            ${m.category || (isInc ? 'Ingreso' : 'Egreso')}
          </span>
        </td>
        <td class="py-2.5 px-3 font-semibold text-on-surface">
          <div>${m.concept || 'Movimiento'}</div>
          ${m.thirdParty ? `<div class="text-[10px] text-on-surface-variant font-normal">Tercero: ${m.thirdParty}</div>` : ''}
        </td>
        <td class="py-2.5 px-3 text-on-surface-variant text-[11px]">
          <div>${getMethodLabel(m.method)}</div>
          ${m.reference ? `<div class="font-mono text-[10px] text-outline">Ref: ${m.reference}</div>` : ''}
        </td>
        <td class="py-2.5 px-3 text-right font-mono whitespace-nowrap">
          <div class="font-extrabold ${isInc ? 'text-emerald-600 dark:text-emerald-400' : 'text-rose-600 dark:text-rose-400'}">
            ${isInc ? '+' : '-'}$${usd.toFixed(2)}
          </div>
          <div class="text-[10px] text-on-surface-variant font-medium">
            ${isInc ? '+' : '-'}${bs.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.
          </div>
        </td>
        <td class="py-2.5 px-3 text-center">
          <button class="btn-del-caja w-7 h-7 rounded-lg bg-surface-container flex items-center justify-center text-on-surface-variant hover:text-rose-500 transition-colors" data-id="${m.id}" title="Eliminar registro">
            <span class="material-symbols-outlined text-[16px]">delete</span>
          </button>
        </td>
      `;
      tbody.appendChild(tr);
    });

    tbody.querySelectorAll('.btn-del-caja').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        if (confirm('¿Deseas eliminar este movimiento de caja?')) {
          state.cashMovements = state.cashMovements.filter(x => x.id !== id);
          saveCashMovementsToStorage();
          renderCajaView();
          showToast('Movimiento eliminado.', 'info');
        }
      });
    });
  }

  function updateCajaCategoryDropdown(type) {
    const sel = document.getElementById('caja-categoria');
    if (!sel) return;
    sel.innerHTML = '';
    const cats = cajaCategories[type] || [];
    cats.forEach(c => {
      const opt = document.createElement('option');
      opt.value = c;
      opt.textContent = c;
      sel.appendChild(opt);
    });
  }

  // ==========================================================================
  // MÓDULO: CUENTAS POR COBRAR (FASE 3 - QUIÉN ME DEBE)
  // ==========================================================================
  function loadCxcFromStorage() {
    if (window.MarktNativeStorage) {
      window.MarktNativeStorage.load('cuentas_por_cobrar.json').then(data => {
        if (data && Array.isArray(data)) state.cuentasPorCobrar = data;
      });
    } else {
      const saved = localStorage.getItem('markt_cuentas_cobrar');
      if (saved) {
        try { state.cuentasPorCobrar = JSON.parse(saved); } catch (e) { state.cuentasPorCobrar = []; }
      }
    }
  }

  function saveCxcToStorage() {
    if (window.MarktNativeStorage) {
      window.MarktNativeStorage.save('cuentas_por_cobrar.json', state.cuentasPorCobrar);
    }
    localStorage.setItem('markt_cuentas_cobrar', JSON.stringify(state.cuentasPorCobrar));
  }

  function renderCxcView() {
    renderCxcSummary();
    renderCxcTable();
  }

  function renderCxcSummary() {
    let totalDebtUsd = 0;
    let countPending = 0;
    let collectedMonthUsd = 0;

    const rate = state.exchange.rate || 1;
    const now = new Date();

    state.cuentasPorCobrar.forEach(c => {
      const bal = Number(c.balanceUsd) || 0;
      if (bal > 0.01) {
        totalDebtUsd += bal;
        countPending++;
      }
      if (c.abonos && Array.isArray(c.abonos)) {
        c.abonos.forEach(ab => {
          if (ab.date) {
            const d = new Date(ab.date);
            if (d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear()) {
              collectedMonthUsd += Number(ab.amountUsd) || 0;
            }
          }
        });
      }
    });

    const elTotalUsd = document.getElementById('cxc-total-usd');
    const elTotalBs = document.getElementById('cxc-total-bs');
    const elClientsCount = document.getElementById('cxc-clients-count');
    const elCollUsd = document.getElementById('cxc-collected-usd');
    const elCollBs = document.getElementById('cxc-collected-bs');

    if (elTotalUsd) elTotalUsd.textContent = `$${totalDebtUsd.toFixed(2)}`;
    if (elTotalBs) elTotalBs.textContent = `${(totalDebtUsd * rate).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.`;
    if (elClientsCount) elClientsCount.textContent = countPending.toString();
    if (elCollUsd) elCollUsd.textContent = `+$${collectedMonthUsd.toFixed(2)}`;
    if (elCollBs) elCollBs.textContent = `+${(collectedMonthUsd * rate).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.`;
  }

  function renderCxcTable() {
    const tbody = document.getElementById('cxc-table-body');
    const emptyState = document.getElementById('cxc-empty-state');
    const countBadge = document.getElementById('cxc-count-badge');
    const search = document.getElementById('search-cxc');
    const q = (search ? search.value : '').toLowerCase().trim();

    if (!tbody) return;
    tbody.innerHTML = '';

    const statusFilter = state.cxcStatusFilter || 'pending';
    let list = state.cuentasPorCobrar.filter(c => {
      const isPaid = (Number(c.balanceUsd) || 0) <= 0.01;
      if (statusFilter === 'pending' && isPaid) return false;
      if (statusFilter === 'paid' && !isPaid) return false;
      if (!q) return true;
      return (c.clientName || '').toLowerCase().includes(q) ||
             (c.docNumber || '').toLowerCase().includes(q) ||
             (c.concept || '').toLowerCase().includes(q) ||
             (c.clientPhone || '').toLowerCase().includes(q);
    });

    if (countBadge) countBadge.textContent = `${list.length} cuentas`;

    if (list.length === 0) {
      if (emptyState) emptyState.classList.remove('hidden');
      return;
    }
    if (emptyState) emptyState.classList.add('hidden');

    const rate = state.exchange.rate || 1;
    const todayStr = new Date().toISOString().split('T')[0];

    list.forEach(c => {
      const bal = Number(c.balanceUsd) || 0;
      const total = Number(c.totalDebtUsd) || 0;
      const paid = Number(c.paidUsd) || 0;
      const isPaid = bal <= 0.01;
      const isOverdue = !isPaid && c.dueDate && c.dueDate < todayStr;

      let badgeHtml = '';
      if (isPaid) {
        badgeHtml = '<span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-500/10 text-emerald-600 dark:text-emerald-400">Saldada</span>';
      } else if (isOverdue) {
        badgeHtml = '<span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-500/10 text-rose-600 dark:text-rose-400 animate-pulse">Vencida</span>';
      } else {
        badgeHtml = '<span class="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-500/10 text-amber-600 dark:text-amber-400">Al día</span>';
      }

      const tr = document.createElement('tr');
      tr.className = 'hover:bg-surface-container/30 transition-colors';
      tr.innerHTML = `
        <td class="py-2.5 px-3">
          <div class="font-bold text-on-surface">${c.clientName || 'Cliente'}</div>
          ${c.clientPhone ? `<div class="text-[10px] text-on-surface-variant font-mono">${c.clientPhone}</div>` : ''}
        </td>
        <td class="py-2.5 px-3 font-medium text-on-surface">
          <div>${c.docNumber ? 'Doc #' + c.docNumber : 'Crédito'}</div>
          ${c.concept ? `<div class="text-[10px] text-on-surface-variant truncate max-w-[120px]">${c.concept}</div>` : ''}
        </td>
        <td class="py-2.5 px-3 text-on-surface-variant font-mono text-[11px] whitespace-nowrap">
          ${c.dueDate || 'Sin plazo'}
        </td>
        <td class="py-2.5 px-3 text-right font-mono font-semibold text-on-surface">$${total.toFixed(2)}</td>
        <td class="py-2.5 px-3 text-right font-mono text-emerald-600 dark:text-emerald-400">+$${paid.toFixed(2)}</td>
        <td class="py-2.5 px-3 text-right font-mono font-extrabold text-rose-600 dark:text-rose-400">
          <div>$${bal.toFixed(2)}</div>
          <div class="text-[10px] text-on-surface-variant font-medium">${(bal * rate).toLocaleString('es-VE', { maximumFractionDigits: 0 })} Bs.</div>
        </td>
        <td class="py-2.5 px-3 text-center">${badgeHtml}</td>
        <td class="py-2.5 px-3 text-center">
          <div class="flex items-center justify-center gap-1">
            ${!isPaid ? `
              <button class="btn-abono-cxc h-7 px-2 rounded-lg bg-primary text-on-primary font-bold text-[10px] flex items-center gap-1 shadow-sm active:scale-95" data-id="${c.id}" title="Registrar abono">
                <span class="material-symbols-outlined text-[13px]">payments</span>
                <span>Abonar</span>
              </button>
              <button class="btn-whatsapp-cxc w-7 h-7 rounded-lg bg-emerald-500/15 text-emerald-600 dark:text-emerald-400 flex items-center justify-center hover:bg-emerald-500/25 transition-colors" data-id="${c.id}" title="Enviar recordatorio WhatsApp">
                <i class="fa-brands fa-whatsapp text-[14px]"></i>
              </button>
            ` : `
              <span class="material-symbols-outlined text-emerald-500 text-[18px]">done_all</span>
            `}
            <button class="btn-del-cxc w-7 h-7 rounded-lg bg-surface-container flex items-center justify-center text-on-surface-variant hover:text-rose-500 transition-colors ml-1" data-id="${c.id}" title="Eliminar registro">
              <span class="material-symbols-outlined text-[15px]">delete</span>
            </button>
          </div>
        </td>
      `;
      tbody.appendChild(tr);
    });

    // Event listeners de acciones
    tbody.querySelectorAll('.btn-abono-cxc').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        openAbonoForm(id);
      });
    });

    tbody.querySelectorAll('.btn-whatsapp-cxc').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        sendCollectionWhatsApp(id);
      });
    });

    tbody.querySelectorAll('.btn-del-cxc').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        if (confirm('¿Deseas eliminar esta cuenta por cobrar?')) {
          state.cuentasPorCobrar = state.cuentasPorCobrar.filter(x => x.id !== id);
          saveCxcToStorage();
          renderCxcView();
          showToast('Cuenta por cobrar eliminada.', 'info');
        }
      });
    });
  }

  function openAbonoForm(cxcId) {
    const item = state.cuentasPorCobrar.find(x => x.id === cxcId);
    if (!item) return;

    const abonoBox = document.getElementById('cxc-abono-box');
    const hiddenId = document.getElementById('abono-cxc-id');
    const clientDisplay = document.getElementById('abono-client-display');
    const docDisplay = document.getElementById('abono-doc-display');
    const balanceDisplay = document.getElementById('abono-balance-display');
    const inputUsd = document.getElementById('abono-monto-usd');
    const inputBs = document.getElementById('abono-monto-bs');

    if (!abonoBox) return;

    hiddenId.value = item.id;
    clientDisplay.textContent = item.clientName || 'Cliente';
    docDisplay.textContent = item.docNumber ? `Comprobante #${item.docNumber}` : (item.concept || 'Deuda');
    balanceDisplay.textContent = `$${(item.balanceUsd || 0).toFixed(2)}`;

    inputUsd.value = '';
    inputBs.value = '';

    abonoBox.classList.remove('hidden');
    abonoBox.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    inputUsd.focus();
  }

  function sendCollectionWhatsApp(cxcId) {
    const item = state.cuentasPorCobrar.find(x => x.id === cxcId);
    if (!item) return;

    const rate = state.exchange.rate || 1;
    const balUsd = Number(item.balanceUsd) || 0;
    const balBs = (balUsd * rate).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const bizName = state.business.name || 'Nuestro Negocio';

    const msg = `Hola estimado(a) ${item.clientName}, un cordial saludo de parte de *${bizName}*.

Le recordamos atentamente que mantiene un saldo pendiente por valor de:
*Monto USD:* $${balUsd.toFixed(2)}
*Monto Bs (BCV):* ${balBs} Bs.
*Concepto:* ${item.docNumber ? 'Doc #' + item.docNumber : item.concept || 'Servicios/Productos'}

Para su comodidad puede realizar su pago mediante:
- Pago Móvil: ${state.suiche.phone || state.business.phone} | RIF: ${state.suiche.docType || 'J'}-${state.suiche.docNumber || ''} | Banco: ${state.suiche.bank || '0134'}
- Efectivo USD o Bs. en nuestra sede.

Por favor envíenos su comprobante una vez realizado. ¡Muchas gracias por su preferencia!`;

    const cleanPhone = (item.clientPhone || '').replace(/[^0-9]/g, '');
    const waUrl = cleanPhone.length >= 10 ?
      `https://wa.me/${cleanPhone}?text=${encodeURIComponent(msg)}` :
      `https://wa.me/?text=${encodeURIComponent(msg)}`;

    window.open(waUrl, '_blank');
  }

  // ==========================================================================
  // MÓDULO: ANALÍTICA & REPORTES GERENCIALES (FASE 5)
  // ==========================================================================
  function renderFinancialReport() {
    const period = state.reportPeriodFilter || 'month';
    const now = new Date();

    const isMatchDate = (dStr) => {
      if (!dStr) return false;
      const d = new Date(dStr);
      if (isNaN(d.getTime())) return false;
      if (period === 'today') return d.toDateString() === now.toDateString();
      if (period === 'week') {
        const diff = (now - d) / (1000 * 60 * 60 * 24);
        return diff >= 0 && diff <= 7;
      }
      if (period === 'month') return d.getMonth() === now.getMonth() && d.getFullYear() === now.getFullYear();
      if (period === 'last_month') {
        const lastMonth = now.getMonth() === 0 ? 11 : now.getMonth() - 1;
        const lastYear = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();
        return d.getMonth() === lastMonth && d.getFullYear() === lastYear;
      }
      return true; // 'all'
    };

    let totalSalesUsd = 0;
    let totalCogsUsd = 0;
    const productStats = {};
    const sellerStats = {};

    // 1. Analizar ventas desde state.history
    state.history.forEach(rec => {
      const recDate = rec.doc_date || (rec.uuid ? new Date(Number(rec.uuid)).toISOString() : null);
      if (!isMatchDate(recDate)) return;

      const grand = Number(rec.total_principal) || 0;
      totalSalesUsd += grand;

      // Seller tracking
      const vName = rec.vendedor || 'Sin Vendedor';
      if (!sellerStats[vName]) sellerStats[vName] = { salesUsd: 0, count: 0, commissionUsd: 0 };
      sellerStats[vName].salesUsd += grand;
      sellerStats[vName].count++;

      // Check seller commission %
      const sellerProfile = state.sellersCatalog.find(s => s.name && s.name.toLowerCase() === vName.toLowerCase());
      const commRate = sellerProfile ? (Number(sellerProfile.prodCommission) || 0) / 100 : 0;
      sellerStats[vName].commissionUsd += (grand * commRate);

      // Cost of goods sold (COGS) & product stats
      if (rec.items && Array.isArray(rec.items)) {
        rec.items.forEach(it => {
          const qty = Number(it.qty) || 1;
          const price = Number(it.price) || 0;
          const pName = it.name || 'Producto';

          // find cost in catalog
          const pCat = state.productsCatalog.find(p => (p.code && p.code === it.code) || (p.name && p.name.toLowerCase() === pName.toLowerCase()));
          const unitCost = pCat ? (Number(pCat.cost) || 0) : 0;
          totalCogsUsd += (unitCost * qty);

          if (!productStats[pName]) productStats[pName] = { qty: 0, totalUsd: 0 };
          productStats[pName].qty += qty;
          productStats[pName].totalUsd += (price * qty);
        });
      }
    });

    // 2. Analizar gastos operativos desde state.cashMovements
    let totalExpensesUsd = 0;
    state.cashMovements.forEach(m => {
      if (m.type === 'expense' && isMatchDate(m.date)) {
        totalExpensesUsd += Number(m.amountUsd) || 0;
      }
    });

    const grossProfitUsd = totalSalesUsd - totalCogsUsd;
    const netProfitUsd = grossProfitUsd - totalExpensesUsd;
    const netMarginPct = totalSalesUsd > 0 ? (netProfitUsd / totalSalesUsd) * 100 : 0;
    const rate = state.exchange.rate || 1;

    // Actualizar UI Cards
    const elSalesUsd = document.getElementById('rep-sales-usd');
    const elSalesBs = document.getElementById('rep-sales-bs');
    const elCostsUsd = document.getElementById('rep-costs-usd');
    const elCostsBs = document.getElementById('rep-costs-bs');
    const elExpUsd = document.getElementById('rep-expenses-usd');
    const elExpBs = document.getElementById('rep-expenses-bs');
    const elProfitUsd = document.getElementById('rep-profit-usd');
    const elProfitMargin = document.getElementById('rep-profit-margin');

    if (elSalesUsd) elSalesUsd.textContent = `$${totalSalesUsd.toFixed(2)}`;
    if (elSalesBs) elSalesBs.textContent = `${(totalSalesUsd * rate).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.`;
    if (elCostsUsd) elCostsUsd.textContent = `$${totalCogsUsd.toFixed(2)}`;
    if (elCostsBs) elCostsBs.textContent = `${(totalCogsUsd * rate).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.`;
    if (elExpUsd) elExpUsd.textContent = `$${totalExpensesUsd.toFixed(2)}`;
    if (elExpBs) elExpBs.textContent = `${(totalExpensesUsd * rate).toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })} Bs.`;
    if (elProfitUsd) {
      elProfitUsd.textContent = `${netProfitUsd >= 0 ? '$' : '-$'}${Math.abs(netProfitUsd).toFixed(2)}`;
      elProfitUsd.className = `font-mono text-2xl font-extrabold ${netProfitUsd >= 0 ? 'text-secondary' : 'text-rose-600 dark:text-rose-400'}`;
    }
    if (elProfitMargin) {
      elProfitMargin.textContent = `Margen Neto Real: ${netMarginPct.toFixed(1)}%`;
      elProfitMargin.className = `text-xs font-bold ${netMarginPct >= 0 ? 'text-on-surface-variant' : 'text-rose-600 dark:text-rose-400'}`;
    }

    // Top Productos
    const topProdList = document.getElementById('rep-top-products-list');
    if (topProdList) {
      topProdList.innerHTML = '';
      const sortedProds = Object.entries(productStats).sort((a, b) => b[1].totalUsd - a[1].totalUsd).slice(0, 5);
      if (sortedProds.length === 0) {
        topProdList.innerHTML = '<p class="text-on-surface-variant text-center py-4">No hay ventas registradas en este período.</p>';
      } else {
        sortedProds.forEach(([name, stat], idx) => {
          const item = document.createElement('div');
          item.className = 'flex items-center justify-between p-2 rounded-xl bg-surface-container-lowest border border-surface-container';
          item.innerHTML = `
            <div class="flex items-center gap-2">
              <span class="w-5 h-5 rounded-full bg-surface-container text-on-surface-variant font-mono font-bold text-[10px] flex items-center justify-center">${idx + 1}</span>
              <div>
                <div class="font-bold text-on-surface truncate max-w-[160px]">${name}</div>
                <div class="text-[10px] text-on-surface-variant">${stat.qty} unidades vendidas</div>
              </div>
            </div>
            <div class="font-mono font-extrabold text-secondary text-right">$${stat.totalUsd.toFixed(2)}</div>
          `;
          topProdList.appendChild(item);
        });
      }
    }

    // Vendedores y Comisiones
    const sellersList = document.getElementById('rep-sellers-list');
    if (sellersList) {
      sellersList.innerHTML = '';
      const sellerEntries = Object.entries(sellerStats);
      if (sellerEntries.length === 0) {
        sellersList.innerHTML = '<p class="text-on-surface-variant text-center py-4">No hay ventas con vendedores asignados.</p>';
      } else {
        sellerEntries.forEach(([name, stat]) => {
          const item = document.createElement('div');
          item.className = 'flex items-center justify-between p-2 rounded-xl bg-surface-container-lowest border border-surface-container';
          item.innerHTML = `
            <div>
              <div class="font-bold text-on-surface">${name}</div>
              <div class="text-[10px] text-on-surface-variant">${stat.count} transacciones | Ventas: $${stat.salesUsd.toFixed(2)}</div>
            </div>
            <div class="text-right">
              <div class="text-[10px] text-on-surface-variant font-semibold">Comisión Ganada</div>
              <div class="font-mono font-extrabold text-emerald-600 dark:text-emerald-400">+$${stat.commissionUsd.toFixed(2)}</div>
            </div>
          `;
          sellersList.appendChild(item);
        });
      }
    }
  }

  // ==========================================================================
  // MÓDULO: ESCÁNER INTELIGENTE DE FACTURAS (OCR - FASE 6)
  // ==========================================================================
  async function scanInvoicePhoto(file) {
    const ocrStatus = document.getElementById('caja-ocr-status');
    const ocrStatusText = document.getElementById('caja-ocr-status-text');
    if (ocrStatus) ocrStatus.classList.remove('hidden');

    try {
      if (typeof Tesseract === 'undefined') {
        throw new Error('Módulo OCR cargando...');
      }

      if (ocrStatusText) ocrStatusText.textContent = 'Analizando texto de factura con IA...';
      const result = await Tesseract.recognize(file, 'spa+eng', {
        logger: m => {
          if (m.status === 'recognizing text' && ocrStatusText) {
            ocrStatusText.textContent = `Leyendo factura: ${Math.round((m.progress || 0) * 100)}%`;
          }
        }
      });

      const text = result.data.text || '';
      parseInvoiceTextAndPopulateExpense(text);
      showToast('Datos de factura extraídos con éxito.', 'success');
    } catch (err) {
      console.warn('OCR fallback or error:', err);
      // Fallback: abrir formulario para llenado directo
      openNewMovementForm('expense', 'Compra de Mercancía / Insumos', 'Gasto por Factura');
      showToast('Completa los datos de la factura manualmente.', 'info');
    } finally {
      if (ocrStatus) ocrStatus.classList.add('hidden');
    }
  }

  function parseInvoiceTextAndPopulateExpense(text) {
    let detectedAmount = 0;
    let detectedRif = '';
    let detectedSupplier = '';

    // Regex para montos
    const amountMatches = text.match(/(?:total|monto|bs|usd|neto)[\s:=]*([0-9]{1,3}(?:[.,][0-9]{3})*[.,][0-9]{2})/i);
    if (amountMatches && amountMatches[1]) {
      const cleaned = amountMatches[1].replace(/\./g, '').replace(',', '.');
      detectedAmount = parseFloat(cleaned) || 0;
    }

    // Regex para RIF venezolano (J-, V-, G-, E-)
    const rifMatch = text.match(/([JVGE]-?[0-9]{7,9}-?[0-9])/i);
    if (rifMatch) detectedRif = rifMatch[1].toUpperCase();

    // Extraer proveedor de primeras líneas
    const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 3);
    if (lines.length > 0) {
      detectedSupplier = lines[0].substring(0, 40);
    }

    // Poblamos el formulario
    openNewMovementForm('expense', 'Compra de Mercancía / Insumos', `Factura: ${detectedSupplier || 'Proveedor'}`);

    const inputUsd = document.getElementById('caja-monto-usd');
    const inputBs = document.getElementById('caja-monto-bs');
    const inputTercero = document.getElementById('caja-tercero');
    const inputRef = document.getElementById('caja-referencia');

    const rate = state.exchange.rate || 1;
    if (detectedAmount > 0) {
      // Si el monto es mayor a 500, asumimos Bs, sino USD
      if (detectedAmount > 200) {
        if (inputBs) inputBs.value = detectedAmount.toFixed(2);
        if (inputUsd) inputUsd.value = (detectedAmount / rate).toFixed(2);
      } else {
        if (inputUsd) inputUsd.value = detectedAmount.toFixed(2);
        if (inputBs) inputBs.value = (detectedAmount * rate).toFixed(2);
      }
    }

    if (inputTercero && (detectedSupplier || detectedRif)) {
      inputTercero.value = `${detectedSupplier} ${detectedRif ? '(' + detectedRif + ')' : ''}`.trim();
    }
    if (inputRef && detectedRif) {
      inputRef.value = detectedRif;
    }
  }

  function openNewMovementForm(type = 'income', category = null, concept = '') {
    const box = document.getElementById('caja-form-box');
    if (!box) return;

    const radIncome = document.querySelector('input[name="caja-tipo"][value="income"]');
    const radExpense = document.querySelector('input[name="caja-tipo"][value="expense"]');
    const lblIncome = document.getElementById('caja-lbl-income');
    const lblExpense = document.getElementById('caja-lbl-expense');

    if (type === 'income') {
      if (radIncome) radIncome.checked = true;
      if (lblIncome) {
        lblIncome.className = 'flex items-center justify-center gap-2 p-2.5 rounded-xl border-2 border-emerald-500 bg-emerald-500/10 cursor-pointer font-bold text-emerald-700 dark:text-emerald-300 text-sm transition-all';
      }
      if (lblExpense) {
        lblExpense.className = 'flex items-center justify-center gap-2 p-2.5 rounded-xl border border-surface-container bg-surface-container-lowest cursor-pointer font-bold text-on-surface-variant text-sm transition-all';
      }
    } else {
      if (radExpense) radExpense.checked = true;
      if (lblExpense) {
        lblExpense.className = 'flex items-center justify-center gap-2 p-2.5 rounded-xl border-2 border-rose-500 bg-rose-500/10 cursor-pointer font-bold text-rose-700 dark:text-rose-300 text-sm transition-all';
      }
      if (lblIncome) {
        lblIncome.className = 'flex items-center justify-center gap-2 p-2.5 rounded-xl border border-surface-container bg-surface-container-lowest cursor-pointer font-bold text-on-surface-variant text-sm transition-all';
      }
    }

    updateCajaCategoryDropdown(type);
    if (category) {
      const sel = document.getElementById('caja-categoria');
      if (sel) sel.value = category;
    }

    const inputConcept = document.getElementById('caja-concepto');
    if (inputConcept) inputConcept.value = concept;

    const inputDate = document.getElementById('caja-fecha');
    if (inputDate) {
      const now = new Date();
      now.setMinutes(now.getMinutes() - now.getTimezoneOffset());
      inputDate.value = now.toISOString().slice(0, 16);
    }

    box.classList.remove('hidden');
    box.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
  }

  // ==========================================================================
  // EVENT LISTENERS DE FASES 2, 3, 5, 6
  // ==========================================================================
  function setupPhases2to6EventListeners() {
    // 1. CAJA: Toggle Formulario
    const btnShowAddCaja = document.getElementById('btn-show-add-caja-form');
    const btnCancelCaja1 = document.getElementById('btn-cancel-caja-form');
    const btnCancelCaja2 = document.getElementById('btn-cancel-caja-form-2');
    const boxCaja = document.getElementById('caja-form-box');

    if (btnShowAddCaja) {
      btnShowAddCaja.addEventListener('click', () => {
        openNewMovementForm('income');
      });
    }
    const hideCajaBox = () => { if (boxCaja) boxCaja.classList.add('hidden'); };
    if (btnCancelCaja1) btnCancelCaja1.addEventListener('click', hideCajaBox);
    if (btnCancelCaja2) btnCancelCaja2.addEventListener('click', hideCajaBox);

    // Tipo radio changes
    document.querySelectorAll('input[name="caja-tipo"]').forEach(rad => {
      rad.addEventListener('change', e => {
        openNewMovementForm(e.target.value);
      });
    });

    // Conversión en vivo USD <-> Bs en formulario de caja
    const inputCajaUsd = document.getElementById('caja-monto-usd');
    const inputCajaBs = document.getElementById('caja-monto-bs');
    if (inputCajaUsd && inputCajaBs) {
      inputCajaUsd.addEventListener('input', () => {
        const rate = state.exchange.rate || 1;
        const val = parseFloat(inputCajaUsd.value) || 0;
        inputCajaBs.value = val > 0 ? (val * rate).toFixed(2) : '';
      });
      inputCajaBs.addEventListener('input', () => {
        const rate = state.exchange.rate || 1;
        const val = parseFloat(inputCajaBs.value) || 0;
        inputCajaUsd.value = val > 0 ? (val / rate).toFixed(2) : '';
      });
    }

    // Submit Nuevo Movimiento
    const formCaja = document.getElementById('form-nuevo-movimiento');
    if (formCaja) {
      formCaja.addEventListener('submit', e => {
        e.preventDefault();
        const typeRad = document.querySelector('input[name="caja-tipo"]:checked');
        const type = typeRad ? typeRad.value : 'income';
        const cat = document.getElementById('caja-categoria').value;
        const concept = document.getElementById('caja-concepto').value.trim();
        const usd = parseFloat(document.getElementById('caja-monto-usd').value) || 0;
        const bs = parseFloat(document.getElementById('caja-monto-bs').value) || (usd * (state.exchange.rate || 1));
        const method = document.getElementById('caja-metodo').value;
        const ref = document.getElementById('caja-referencia').value.trim();
        const third = document.getElementById('caja-tercero').value.trim();
        const dateVal = document.getElementById('caja-fecha').value;

        if (usd <= 0) {
          showToast('El monto debe ser mayor a 0', 'error');
          return;
        }

        const newMov = {
          id: 'caja_' + Date.now().toString(),
          date: dateVal ? new Date(dateVal).toISOString() : new Date().toISOString(),
          type,
          category: cat,
          concept,
          amountUsd: usd,
          amountBs: bs,
          method,
          reference: ref,
          thirdParty: third
        };

        state.cashMovements.unshift(newMov);
        saveCashMovementsToStorage();
        renderCajaView();
        hideCajaBox();
        formCaja.reset();
        showToast('Movimiento registrado con éxito.', 'success');
      });
    }

    // Filtros de Caja
    const filterCajaPeriod = document.getElementById('filter-caja-periodo');
    if (filterCajaPeriod) {
      filterCajaPeriod.addEventListener('change', e => {
        state.cajaPeriodFilter = e.target.value;
        renderCajaView();
      });
    }
    const filterCajaType = document.getElementById('filter-caja-tipo');
    if (filterCajaType) {
      filterCajaType.addEventListener('change', e => {
        state.cajaTypeFilter = e.target.value;
        renderCajaTable();
      });
    }
    const searchCaja = document.getElementById('search-caja');
    if (searchCaja) {
      searchCaja.addEventListener('input', () => renderCajaTable());
    }

    // Escáner OCR de Facturas
    const btnScanBill = document.getElementById('btn-caja-scan-bill');
    const inputOcr = document.getElementById('input-caja-camera-ocr');
    if (btnScanBill && inputOcr) {
      btnScanBill.addEventListener('click', () => inputOcr.click());
      inputOcr.addEventListener('change', e => {
        if (e.target.files && e.target.files[0]) {
          scanInvoicePhoto(e.target.files[0]);
          inputOcr.value = '';
        }
      });
    }

    // Compartir Arqueo de Caja
    const btnShareCaja = document.getElementById('btn-share-caja-summary');
    if (btnShareCaja) {
      btnShareCaja.addEventListener('click', () => {
        const period = state.cajaPeriodFilter || 'month';
        const filtered = filterCashMovementsByPeriod(state.cashMovements, period);
        let incUsd = 0;
        let expUsd = 0;
        filtered.forEach(m => {
          if (m.type === 'income') incUsd += Number(m.amountUsd) || 0;
          else expUsd += Number(m.amountUsd) || 0;
        });
        const net = incUsd - expUsd;
        const rate = state.exchange.rate || 1;
        const biz = state.business.name || 'Mi Negocio';

        const txt = `*ARQUEO DE CAJA - ${biz.toUpperCase()}*
*Período:* ${period.toUpperCase()}
*Total Ingresos:* +$${incUsd.toFixed(2)} (+${(incUsd * rate).toLocaleString('es-VE', { maximumFractionDigits: 0 })} Bs.)
*Total Gastos:* -$${expUsd.toFixed(2)} (-${(expUsd * rate).toLocaleString('es-VE', { maximumFractionDigits: 0 })} Bs.)
*Saldo Neto Disponible:* ${net >= 0 ? '$' : '-$'}${Math.abs(net).toFixed(2)} (${(net * rate).toLocaleString('es-VE', { maximumFractionDigits: 0 })} Bs.)
*Tasa BCV:* ${rate.toFixed(2)} Bs./$
Generado por MARKT Universal OS`;

        if (navigator.share) {
          navigator.share({ title: 'Arqueo de Caja', text: txt }).catch(() => {});
        } else {
          navigator.clipboard.writeText(txt);
          showToast('Arqueo copiado al portapapeles.', 'success');
        }
      });
    }

    // 2. CUENTAS POR COBRAR: Toggle Nueva Cuenta Form
    const btnShowCxc = document.getElementById('btn-show-add-cxc-form');
    const btnCancelCxc1 = document.getElementById('btn-cancel-cxc-form');
    const btnCancelCxc2 = document.getElementById('btn-cancel-cxc-form-2');
    const boxCxc = document.getElementById('cxc-form-box');

    if (btnShowCxc) {
      btnShowCxc.addEventListener('click', () => {
        if (boxCxc) boxCxc.classList.remove('hidden');
      });
    }
    const hideCxcBox = () => { if (boxCxc) boxCxc.classList.add('hidden'); };
    if (btnCancelCxc1) btnCancelCxc1.addEventListener('click', hideCxcBox);
    if (btnCancelCxc2) btnCancelCxc2.addEventListener('click', hideCxcBox);

    // Cancel Abono box
    const btnCancelAb1 = document.getElementById('btn-cancel-abono-box');
    const btnCancelAb2 = document.getElementById('btn-cancel-abono-box-2');
    const boxAb = document.getElementById('cxc-abono-box');
    const hideAbBox = () => { if (boxAb) boxAb.classList.add('hidden'); };
    if (btnCancelAb1) btnCancelAb1.addEventListener('click', hideAbBox);
    if (btnCancelAb2) btnCancelAb2.addEventListener('click', hideAbBox);

    // Conversión Abono USD <-> Bs
    const inputAbUsd = document.getElementById('abono-monto-usd');
    const inputAbBs = document.getElementById('abono-monto-bs');
    if (inputAbUsd && inputAbBs) {
      inputAbUsd.addEventListener('input', () => {
        const rate = state.exchange.rate || 1;
        const val = parseFloat(inputAbUsd.value) || 0;
        inputAbBs.value = val > 0 ? (val * rate).toFixed(2) : '';
      });
      inputAbBs.addEventListener('input', () => {
        const rate = state.exchange.rate || 1;
        const val = parseFloat(inputAbBs.value) || 0;
        inputAbUsd.value = val > 0 ? (val / rate).toFixed(2) : '';
      });
    }

    // Submit Nueva Cuenta por Cobrar
    const formCxc = document.getElementById('form-nueva-cuenta-cobrar');
    if (formCxc) {
      formCxc.addEventListener('submit', e => {
        e.preventDefault();
        const clientName = document.getElementById('cxc-client-name').value.trim();
        const clientPhone = document.getElementById('cxc-client-phone').value.trim();
        const docRef = document.getElementById('cxc-doc-ref').value.trim();
        const total = parseFloat(document.getElementById('cxc-total-debt-usd').value) || 0;
        const initPay = parseFloat(document.getElementById('cxc-initial-payment-usd').value) || 0;
        const dueDate = document.getElementById('cxc-due-date').value;
        const concept = document.getElementById('cxc-concept').value.trim();

        if (total <= 0) {
          showToast('El monto de la deuda debe ser mayor a 0', 'error');
          return;
        }

        const bal = Math.max(0, total - initPay);
        const newRecord = {
          id: 'cxc_' + Date.now().toString(),
          receiptId: null,
          docNumber: docRef || 'C-001',
          clientName,
          clientPhone,
          date: new Date().toISOString().split('T')[0],
          dueDate: dueDate || new Date(Date.now() + 15 * 86400000).toISOString().split('T')[0],
          totalDebtUsd: total,
          paidUsd: initPay,
          balanceUsd: bal,
          concept: concept || 'Venta a crédito',
          status: bal <= 0.01 ? 'paid' : 'pending',
          abonos: initPay > 0 ? [{
            date: new Date().toISOString(),
            amountUsd: initPay,
            method: 'efectivo_usd',
            reference: 'Inicial'
          }] : []
        };

        state.cuentasPorCobrar.unshift(newRecord);
        saveCxcToStorage();

        // Si pagó inicial, registrar en caja
        if (initPay > 0) {
          const cashEntry = {
            id: 'caja_ab_' + Date.now().toString(),
            date: new Date().toISOString(),
            type: 'income',
            category: 'Abono / Anticipo de Inicial',
            concept: `Abono Inicial Crédito #${newRecord.docNumber} - ${clientName}`,
            amountUsd: initPay,
            amountBs: initPay * (state.exchange.rate || 1),
            method: 'efectivo_usd',
            reference: 'Inicial',
            thirdParty: clientName
          };
          state.cashMovements.unshift(cashEntry);
          saveCashMovementsToStorage();
        }

        renderCxcView();
        hideCxcBox();
        formCxc.reset();
        showToast('Cuenta por cobrar registrada.', 'success');
      });
    }

    // Submit Abono a Deuda
    const formAbono = document.getElementById('form-registrar-abono');
    if (formAbono) {
      formAbono.addEventListener('submit', e => {
        e.preventDefault();
        const cxcId = document.getElementById('abono-cxc-id').value;
        const item = state.cuentasPorCobrar.find(x => x.id === cxcId);
        if (!item) return;

        const usd = parseFloat(document.getElementById('abono-monto-usd').value) || 0;
        const bs = parseFloat(document.getElementById('abono-monto-bs').value) || (usd * (state.exchange.rate || 1));
        const method = document.getElementById('abono-metodo').value;
        const ref = document.getElementById('abono-referencia').value.trim();
        const autoCaja = document.getElementById('abono-auto-caja').checked;

        if (usd <= 0) {
          showToast('El monto del abono debe ser mayor a 0', 'error');
          return;
        }

        item.paidUsd = (Number(item.paidUsd) || 0) + usd;
        item.balanceUsd = Math.max(0, (Number(item.totalDebtUsd) || 0) - item.paidUsd);
        if (item.balanceUsd <= 0.01) item.status = 'paid';

        if (!item.abonos) item.abonos = [];
        item.abonos.push({
          date: new Date().toISOString(),
          amountUsd: usd,
          amountBs: bs,
          method,
          reference: ref
        });

        saveCxcToStorage();

        // Ingreso en Caja automático
        if (autoCaja) {
          const cashEntry = {
            id: 'caja_abono_' + Date.now().toString(),
            date: new Date().toISOString(),
            type: 'income',
            category: 'Cobro a Cliente / Abono Factura',
            concept: `Abono Deuda #${item.docNumber} - ${item.clientName}`,
            amountUsd: usd,
            amountBs: bs,
            method,
            reference: ref || 'Abono',
            thirdParty: item.clientName
          };
          state.cashMovements.unshift(cashEntry);
          saveCashMovementsToStorage();
        }

        renderCxcView();
        hideAbBox();
        formAbono.reset();
        showToast('Abono registrado con éxito.', 'success');
      });
    }

    // Filtros de CxC
    const filterCxcStatus = document.getElementById('filter-cxc-status');
    if (filterCxcStatus) {
      filterCxcStatus.addEventListener('change', e => {
        state.cxcStatusFilter = e.target.value;
        renderCxcTable();
      });
    }
    const searchCxc = document.getElementById('search-cxc');
    if (searchCxc) {
      searchCxc.addEventListener('input', () => renderCxcTable());
    }

    // 3. REPORTES: Filtro y Compartir
    const filterReport = document.getElementById('report-period-filter');
    if (filterReport) {
      filterReport.addEventListener('change', e => {
        state.reportPeriodFilter = e.target.value;
        renderFinancialReport();
      });
    }

    const btnShareReport = document.getElementById('btn-share-report');
    if (btnShareReport) {
      btnShareReport.addEventListener('click', () => {
        const period = state.reportPeriodFilter || 'month';
        const elSales = document.getElementById('rep-sales-usd');
        const elCosts = document.getElementById('rep-costs-usd');
        const elExp = document.getElementById('rep-expenses-usd');
        const elProfit = document.getElementById('rep-profit-usd');
        const elMargin = document.getElementById('rep-profit-margin');
        const biz = state.business.name || 'Mi Negocio';

        const txt = `*INFORME FINANCIERO - ${biz.toUpperCase()}*
*Período:* ${period.toUpperCase()}
*Ventas Totales:* ${elSales ? elSales.textContent : '$0.00'}
*Costo de Mercancía:* ${elCosts ? elCosts.textContent : '$0.00'}
*Gastos Operativos:* ${elExp ? elExp.textContent : '$0.00'}
*UTILIDAD NETA REAL:* ${elProfit ? elProfit.textContent : '$0.00'}
*${elMargin ? elMargin.textContent : ''}*
Generado por MARKT Universal OS`;

        if (navigator.share) {
          navigator.share({ title: 'Informe Financiero', text: txt }).catch(() => {});
        } else {
          navigator.clipboard.writeText(txt);
          showToast('Informe financiero copiado al portapapeles.', 'success');
        }
      });
    }

    // 4. CONVERTIR COTIZACIÓN A VENTA POS
    const btnConvertQuoteToPos = document.getElementById('btn-convert-quote-to-pos');
    if (btnConvertQuoteToPos) {
      btnConvertQuoteToPos.addEventListener('click', () => {
        if (!state.activeQuote) {
          showToast('No hay una cotización activa.', 'error');
          return;
        }
        if (state.activeQuote.clientName) state.client.name = state.activeQuote.clientName;
        if (state.activeQuote.clientId) state.client.id = state.activeQuote.clientId;
        if (state.activeQuote.clientPhone) state.client.phone = state.activeQuote.clientPhone;
        if (state.activeQuote.clientCity) state.client.city = state.activeQuote.clientCity;

        if (state.activeQuote.items && state.activeQuote.items.length > 0) {
          state.items = state.activeQuote.items.map(it => ({
            code: it.code || 'COT',
            name: it.name || it.desc || 'Producto / Servicio',
            qty: Number(it.qty) || 1,
            price: Number(it.price) || 0,
            unit: it.unit || 'und',
            cost: Number(it.cost) || 0
          }));
        }

        state.activeQuote.status = 'Aprobado';
        saveCotizacionesToStorage();
        renderItemsList();
        updateCalculationsAndPreview();
        switchView('view-pos');
        showToast('Cotización cargada en el Terminal POS lista para facturar.', 'success');
      });
    }

    // 5. BANNER NOVEDADES V4.0
    const banner = document.getElementById('v4-welcome-banner');
    const btnViewV4 = document.getElementById('btn-view-v4-changelog');
    const btnDismissV4 = document.getElementById('btn-dismiss-v4-banner');

    if (banner) {
      const seen = localStorage.getItem('markt_v4_changelog_seen');
      if (!seen) banner.classList.remove('hidden');

      if (btnViewV4) {
        btnViewV4.addEventListener('click', () => {
          localStorage.setItem('markt_v4_changelog_seen', 'true');
          banner.classList.add('hidden');
          switchView('view-changelog');
        });
      }
      if (btnDismissV4) {
        btnDismissV4.addEventListener('click', () => {
          localStorage.setItem('markt_v4_changelog_seen', 'true');
          banner.classList.add('hidden');
        });
      }
    }
  }
