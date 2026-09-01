/* ==========================================================================
   MARTK - Admin Panel POS & Gestión Integral (Engine JavaScript)
   ========================================================================== */

document.addEventListener('DOMContentLoaded', () => {

  const API_BASE_URL = 'http://localhost:5000/api';

  // --- STATE SYSTEM ---
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
      docNumber: 'No. FES-001',
      currency: '$',
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
      targetCurrency: 'USD',
      rate: 798.33,
      showDual: true,
      bcvUsd: 798.33,
      bcvEur: 926.55
    },
    suiche: {
      bank: '0134',
      docType: 'J',
      docNumber: '',
      phone: '',
      amountMode: 'dynamic'
    },
    items: [
      {
        id: '1',
        cant: 1,
        desc: '',
        subtext: '',
        taxRate: 16,
        unitPrice: 0
      }
    ],
    paymentDetails: {
      concept: '',
      amount: 0,
      ref: '',
      prevBalance: 0,
      newBalance: 0
    },
    totals: {
      subtotal: 0,
      taxRate: 16,
      taxAmount: 0,
      discount: 0,
      grandTotal: 0
    },
    options: {
      logoSize: 220,
      showBarcode: true,
      showQR: true,
      showSignature: true,
      showTaxTable: true,
      theme: 'theme-thermal',
      notes: 'Montos calculados según tasa oficial de referencia BCV.\nGracias por su compra.'
    },
    productsCatalog: [],
    clientsCatalog: [],
    history: []
  };

  // Helper function to format Folio: 1 -> "No. FES-001"
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
  const btnSidebarFetchBcv = document.getElementById('btn-sidebar-fetch-bcv');
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
    loadSavedSettingsAndBusiness();
    loadProductsFromStorage();
    loadClientsFromStorage();
    loadHistoryFromStorage();
    setupNavigation();
    setupSubtabsSystem();
    setupDocTypeSelector();
    setupEventListeners();
    setDefaultDateAndTime();
    renderItemsList();
    fetchBcvRatesFromApi();
    updateCalculationsAndPreview();
  }

  function setDefaultDateAndTime() {
    if (!inputDocDate.value) inputDocDate.value = state.client.date;
    if (!inputDocTime.value) inputDocTime.value = state.client.time;
  }

  // --- SUBTABS & STEP WIZARD NAVIGATION ---
  let maxReachedStep = 1;

  function setupSubtabsSystem() {
    const switchSubtabByStep = (targetStepNum) => {
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
          switchSubtabByStep(stepNum);
        }
      });
    });

    if (btnNextStep1) btnNextStep1.addEventListener('click', () => switchSubtabByStep(2));
    if (btnNextStep2) btnNextStep2.addEventListener('click', () => switchSubtabByStep(3));
    if (btnPrevStep2) btnPrevStep2.addEventListener('click', () => switchSubtabByStep(1));
    if (btnPrevStep3) btnPrevStep3.addEventListener('click', () => switchSubtabByStep(2));

    // Inicializar en Paso 1
    switchSubtabByStep(1);
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

      mobileNavBtns.forEach(btn => {
        if (btn.getAttribute('data-view') === targetView) btn.classList.add('active');
        else btn.classList.remove('active');
      });

      if (targetView === 'view-pos') {
        pageTitleText.textContent = 'Punto de Venta POS';
        pageSubtitleText.textContent = 'Emisión y vista previa interactiva de facturas, recibos y egresos';
      } else if (targetView === 'view-productos') {
        pageTitleText.textContent = 'Catálogo de Productos';
        pageSubtitleText.textContent = 'Gestiona tus productos o servicios con precios en $ USD';
        renderProductsTable();
      } else if (targetView === 'view-clientes') {
        pageTitleText.textContent = 'Directorio de Clientes';
        pageSubtitleText.textContent = 'Consulta y administra el directorio de tus clientes';
        renderClientsTable();
      } else if (targetView === 'view-historial') {
        pageTitleText.textContent = 'Historial de Comprobantes';
        pageSubtitleText.textContent = 'Registro completo de comprobantes emitidos';
        renderHistoryTable();
      } else if (targetView === 'view-ajustes') {
        pageTitleText.textContent = 'Ajustes & Preferencias Permanentes';
        pageSubtitleText.textContent = 'Configura el logo, datos y opciones de impresión';
      }

      adminSidebar.classList.remove('mobile-open');
      sidebarOverlay.classList.remove('mobile-open');
    };

    navItems.forEach(item => {
      item.addEventListener('click', () => switchView(item.getAttribute('data-view')));
    });

    mobileNavBtns.forEach(btn => {
      btn.addEventListener('click', () => switchView(btn.getAttribute('data-view')));
    });

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
  async function performCedulaLookup() {
    const rawVal = (inputClientId.value || '').trim();
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
      return;
    }

    showToast('Buscando en directorio...', 'info');

    try {
      const res = await fetch(`${API_BASE_URL}/consultar-cedula/${encodeURIComponent(rawVal)}`);
      const data = await res.json();

      if (data.success && data.nombre && data.nombre.length > 2 && !data.nombre.includes('&')) {
        state.client.name = data.nombre;
        inputClientName.value = data.nombre;

        if (data.doc) {
          state.client.id = data.doc;
          inputClientId.value = data.doc;
        }
        if (data.telefono) {
          state.client.phone = data.telefono;
          inputClientPhone.value = data.telefono;
        }
        if (data.direccion) {
          state.client.city = data.direccion;
          inputClientCity.value = data.direccion;
        }

        updateCalculationsAndPreview();
        showToast(`Cliente encontrado en directorio: ${data.nombre}`, 'success');

      } else {
        showToast('Cliente nuevo. Ingresa el nombre para guardarlo.', 'info');
        inputClientName.focus();
      }
    } catch (err) {
      showToast('Ingresa el nombre del cliente.', 'info');
      inputClientName.focus();
    }
  }

  // --- BCV INTEGRATION ---
  async function fetchBcvRatesFromApi() {
    sidebarBcvUsd.textContent = 'Consultando...';
    sidebarBcvEur.textContent = 'Consultando...';

    try {
      const res = await fetch('https://ve.dolarapi.com/v1/cotizaciones');
      if (!res.ok) throw new Error('Error de red');
      const data = await res.json();

      const usdObj = data.find(d => d.moneda === 'USD' && d.fuente === 'oficial');
      const eurObj = data.find(d => d.moneda === 'EUR' && d.fuente === 'oficial');

      if (usdObj && usdObj.promedio) {
        state.exchange.bcvUsd = usdObj.promedio;
        sidebarBcvUsd.textContent = `${usdObj.promedio.toFixed(2)} Bs.`;
      }
      if (eurObj && eurObj.promedio) {
        state.exchange.bcvEur = eurObj.promedio;
        sidebarBcvEur.textContent = `${eurObj.promedio.toFixed(2)} Bs.`;
      }

      state.exchange.rate = state.exchange.bcvUsd;
      updateCalculationsAndPreview();
      showToast(`Tasa BCV actualizada: ${state.exchange.bcvUsd.toFixed(2)} Bs.`, 'success');
    } catch (err) {
      sidebarBcvUsd.textContent = `${state.exchange.bcvUsd.toFixed(2)} Bs.`;
      sidebarBcvEur.textContent = `${state.exchange.bcvEur.toFixed(2)} Bs.`;
    }
  }

  if (btnSidebarFetchBcv) btnSidebarFetchBcv.addEventListener('click', fetchBcvRatesFromApi);

  // --- DOCUMENT TYPE SELECTOR SWITCHING ---
  function setupDocTypeSelector() {
    docTypeBtns.forEach(btn => {
      btn.addEventListener('click', () => {
        docTypeBtns.forEach(b => b.classList.remove('active'));
        btn.classList.add('active');

        const type = btn.getAttribute('data-doctype');
        setDocumentType(type);
      });
    });
  }

  function setDocumentType(type) {
    state.docType = type;

    if (type === 'venta') {
      docTypeTitleText.textContent = 'Factura de Venta';
      state.business.docTitle = 'FACTURA ELECTRÓNICA DE VENTA';
      sectionVentaItems.classList.remove('hidden');
      sectionPaymentDetails.classList.add('hidden');

      if (tabPersonText) tabPersonText.textContent = 'Cliente';
      if (tabItemsText) tabItemsText.textContent = 'Productos';
      if (tabItemsIcon) tabItemsIcon.className = 'fa-solid fa-list-check';
      if (sectionPersonTitle) sectionPersonTitle.textContent = 'Datos del Cliente & Pago';
      if (lblClientId) lblClientId.textContent = 'Documento / C.I. / RIF';
      if (lblClientName) lblClientName.textContent = 'Nombre del Cliente *';
      if (btnNextStepText) btnNextStepText.textContent = 'Siguiente: Productos';
      if (btnPrevStep2Text) btnPrevStep2Text.textContent = 'Anterior: Cliente';
      if (btnPrevStep3Text) btnPrevStep3Text.textContent = 'Anterior: Productos';

    } else if (type === 'ingreso') {
      docTypeTitleText.textContent = 'Recibo de Caja (Cobro)';
      state.business.docTitle = 'RECIBO DE CAJA / COMPROBANTE DE INGRESO';
      sectionVentaItems.classList.add('hidden');
      sectionPaymentDetails.classList.remove('hidden');

      if (tabPersonText) tabPersonText.textContent = 'Cliente';
      if (tabItemsText) tabItemsText.textContent = 'Detalle Cobro';
      if (tabItemsIcon) tabItemsIcon.className = 'fa-solid fa-money-bill-wave';
      if (sectionPersonTitle) sectionPersonTitle.textContent = 'Datos del Cliente / Pagador';
      if (lblClientId) lblClientId.textContent = 'Documento / C.I. / RIF';
      if (lblClientName) lblClientName.textContent = 'Nombre del Cliente *';
      if (btnNextStepText) btnNextStepText.textContent = 'Siguiente: Detalle del Cobro';
      if (btnPrevStep2Text) btnPrevStep2Text.textContent = 'Anterior: Cliente';
      if (btnPrevStep3Text) btnPrevStep3Text.textContent = 'Anterior: Detalle Cobro';

    } else if (type === 'egreso') {
      docTypeTitleText.textContent = 'Comprobante de Egreso';
      state.business.docTitle = 'COMPROBANTE DE EGRESO DE CAJA';
      sectionVentaItems.classList.add('hidden');
      sectionPaymentDetails.classList.remove('hidden');

      if (tabPersonText) tabPersonText.textContent = 'Beneficiario';
      if (tabItemsText) tabItemsText.textContent = 'Detalle Egreso';
      if (tabItemsIcon) tabItemsIcon.className = 'fa-solid fa-money-bill-transfer';
      if (sectionPersonTitle) sectionPersonTitle.textContent = 'Datos del Beneficiario';
      if (lblClientId) lblClientId.textContent = 'Documento / RIF / C.I.';
      if (lblClientName) lblClientName.textContent = 'Nombre / Razón Social *';
      if (btnNextStepText) btnNextStepText.textContent = 'Siguiente: Detalle del Egreso';
      if (btnPrevStep2Text) btnPrevStep2Text.textContent = 'Anterior: Beneficiario';
      if (btnPrevStep3Text) btnPrevStep3Text.textContent = 'Anterior: Detalle Egreso';
    }

    state.business.docNumber = formatFolioNumber(state.folioCounter);
    if (posDocNumber) posDocNumber.textContent = state.business.docNumber;
    if (inputDocNumber) inputDocNumber.value = state.business.docNumber;

    updateCalculationsAndPreview();
  }

  // --- EVENT LISTENERS ---
  function setupEventListeners() {
    inputClientName.addEventListener('input', e => { state.client.name = e.target.value; updateCalculationsAndPreview(); });
    inputClientId.addEventListener('input', e => { state.client.id = e.target.value; updateCalculationsAndPreview(); });
    inputClientId.addEventListener('keyup', e => { if (e.key === 'Enter') performCedulaLookup(); });
    if (btnSearchCedula) btnSearchCedula.addEventListener('click', performCedulaLookup);

    inputClientPhone.addEventListener('input', e => { state.client.phone = e.target.value; });
    inputClientCity.addEventListener('input', e => { state.client.city = e.target.value; updateCalculationsAndPreview(); });

    selectPaymentForm.addEventListener('change', e => {
      if (e.target.value === 'custom') {
        customPaymentWrapper.classList.remove('hidden');
        state.client.paymentForm = inputCustomPaymentName.value || 'Otro';
      } else {
        customPaymentWrapper.classList.add('hidden');
        state.client.paymentForm = e.target.value;
      }
      updateCalculationsAndPreview();
    });

    inputCustomPaymentName.addEventListener('input', e => {
      if (selectPaymentForm.value === 'custom') {
        state.client.paymentForm = e.target.value || 'Otro';
        updateCalculationsAndPreview();
      }
    });

    inputSalesperson.addEventListener('input', e => { state.client.salesperson = e.target.value; updateCalculationsAndPreview(); });
    inputDocDate.addEventListener('change', e => { state.client.date = e.target.value; updateCalculationsAndPreview(); });
    inputDocTime.addEventListener('input', e => { state.client.time = e.target.value; updateCalculationsAndPreview(); });

    inputTaxRate.addEventListener('input', e => { state.totals.taxRate = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });
    inputDiscountAmount.addEventListener('input', e => { state.totals.discount = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });

    inputPaymentConcept.addEventListener('input', e => { state.paymentDetails.concept = e.target.value; updateCalculationsAndPreview(); });
    inputPaymentAmount.addEventListener('input', e => { state.paymentDetails.amount = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });
    inputPaymentRef.addEventListener('input', e => { state.paymentDetails.ref = e.target.value; updateCalculationsAndPreview(); });
    inputPrevBalance.addEventListener('input', e => { state.paymentDetails.prevBalance = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });
    inputNewBalance.addEventListener('input', e => { state.paymentDetails.newBalance = parseFloat(e.target.value) || 0; updateCalculationsAndPreview(); });

    selectSuicheBank.addEventListener('change', e => { state.suiche.bank = e.target.value; updateCalculationsAndPreview(); });
    selectSuicheDocType.addEventListener('change', e => { state.suiche.docType = e.target.value; updateCalculationsAndPreview(); });
    inputSuicheDocNumber.addEventListener('input', e => { state.suiche.docNumber = e.target.value; updateCalculationsAndPreview(); });
    inputSuichePhone.addEventListener('input', e => { state.suiche.phone = e.target.value; updateCalculationsAndPreview(); });
    selectSuicheAmountMode.addEventListener('change', e => { state.suiche.amountMode = e.target.value; updateCalculationsAndPreview(); });

    inputBizName.addEventListener('input', e => { state.business.name = e.target.value; updateCalculationsAndPreview(); });
    inputBizId.addEventListener('input', e => { state.business.id = e.target.value; updateCalculationsAndPreview(); });
    inputBizPhone.addEventListener('input', e => { state.business.phone = e.target.value; updateCalculationsAndPreview(); });
    inputBizAddress.addEventListener('input', e => { state.business.address = e.target.value; updateCalculationsAndPreview(); });
    inputFooterNotes.addEventListener('input', e => { state.options.notes = e.target.value; updateCalculationsAndPreview(); });

    logoSizeRange.addEventListener('input', e => {
      const val = parseInt(e.target.value) || 220;
      state.options.logoSize = val;
      logoSizeVal.textContent = `${val} px`;
      updateCalculationsAndPreview();
    });

    prefShowQr.addEventListener('change', e => { state.options.showQR = e.target.checked; updateCalculationsAndPreview(); });
    prefShowBarcode.addEventListener('change', e => { state.options.showBarcode = e.target.checked; updateCalculationsAndPreview(); });
    prefShowSignature.addEventListener('change', e => { state.options.showSignature = e.target.checked; updateCalculationsAndPreview(); });
    prefShowTaxTable.addEventListener('change', e => { state.options.showTaxTable = e.target.checked; updateCalculationsAndPreview(); });

    themeCards.forEach(card => {
      card.addEventListener('click', () => {
        themeCards.forEach(c => c.classList.remove('active'));
        card.classList.add('active');
        const theme = card.getAttribute('data-theme');
        state.options.theme = theme;
        ticketCard.className = `ticket-card ${state.options.theme}`;
      });
    });

    inputDocNumber.addEventListener('input', e => { state.business.docNumber = e.target.value; updateCalculationsAndPreview(); });
    inputFolioCounter.addEventListener('input', e => {
      const val = parseInt(e.target.value) || 1;
      state.folioCounter = val;
      state.business.docNumber = formatFolioNumber(val);
      if (posDocNumber) posDocNumber.textContent = state.business.docNumber;
      if (inputDocNumber) inputDocNumber.value = state.business.docNumber;
      updateCalculationsAndPreview();
    });

    inputLogo.addEventListener('change', handleLogoUpload);
    btnRemoveLogo.addEventListener('click', handleLogoRemove);
    btnSaveAllSettings.addEventListener('click', saveAllSettingsPermanently);

    btnAddItem.addEventListener('click', () => {
      state.items.push({
        id: Date.now().toString(),
        cant: 1,
        desc: '',
        subtext: '',
        taxRate: 16,
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
  }

  // --- ITEMS LIST RENDERER IN POS ---
  function renderItemsList() {
    itemsListContainer.innerHTML = '';

    state.items.forEach(item => {
      const card = document.createElement('div');
      card.className = 'item-row-card';
      card.innerHTML = `
        <div class="item-row-header">
          <input type="text" class="item-desc-input" placeholder="Descripción del producto o servicio..." value="${escapeHtml(item.desc)}" data-id="${item.id}" data-field="desc">
          <button type="button" class="btn-remove-item" data-id="${item.id}" title="Eliminar ítem">
            <i class="fa-solid fa-trash"></i>
          </button>
        </div>
        <div class="item-row-details">
          <div>
            <label>Cant.</label>
            <input type="number" min="1" step="1" value="${item.cant}" data-id="${item.id}" data-field="cant">
          </div>
          <div>
            <label>Subtexto / Nota</label>
            <input type="text" placeholder="Ej: Garantía 6 meses" value="${escapeHtml(item.subtext || '')}" data-id="${item.id}" data-field="subtext">
          </div>
          <div>
            <label>Precio ($ USD)</label>
            <input type="number" min="0" step="0.01" value="${item.unitPrice || ''}" placeholder="0.00 $" data-id="${item.id}" data-field="unitPrice">
          </div>
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
          if (field === 'cant' || field === 'unitPrice') {
            item[field] = parseFloat(e.target.value) || 0;
          } else {
            item[field] = e.target.value;
          }
          updateCalculationsAndPreview();
        }
      });
    });

    itemsListContainer.querySelectorAll('.btn-remove-item').forEach(btn => {
      btn.addEventListener('click', () => {
        const id = btn.getAttribute('data-id');
        if (state.items.length <= 1) {
          showToast('Debe haber al menos un ítem.', 'info');
          return;
        }
        state.items = state.items.filter(i => i.id !== id);
        renderItemsList();
        updateCalculationsAndPreview();
      });
    });
  }

  // --- CALCULATIONS & PREVIEW BINDING ---
  function updateCalculationsAndPreview() {
    const c = state.business.currency || '$';
    const rate = state.exchange.rate > 0 ? state.exchange.rate : 1;

    const fmtBs = num => `Bs. ${num.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    const fmtInputCurr = num => `${c} ${num.toLocaleString('es-VE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

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
      viewTaxRow.classList.remove('hidden');
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
            <span class="col-tax">${taxRate > 0 ? taxRate + '%' : '0'}</span>
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

      viewTax.textContent = fmtInputCurr(taxAmount);
      viewTotal.textContent = `${fmtInputCurr(grandTotalMain)} USD`;
      viewItemsCount.textContent = state.items.length;

      if (state.options.showTaxTable) {
        viewTaxTableWrapper.classList.remove('hidden');
        viewTaxRateLbl.textContent = taxRate > 0 ? `IVA ${taxRate}%` : 'EXCLUIDO 0%';
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
      viewDualTitle.textContent = `Equivalente en Bolívares (BCV):`;
      viewUsdTotal.textContent = fmtBs(totalBs);
      viewExchangeRateLbl.textContent = `Tasa Ref BCV (USD): 1 USD = ${rate.toFixed(2)} Bs.`;
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
      viewNotesWrapper.classList.remove('hidden');
      viewNotesText.textContent = state.options.notes;
    } else {
      viewNotesWrapper.classList.add('hidden');
    }
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

  // --- LOGO UPLOAD & REMOVE ---
  function handleLogoUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    if (file.size > 3 * 1024 * 1024) {
      showToast('La imagen supera los 3MB.', 'info');
      return;
    }

    const reader = new FileReader();
    reader.onload = function (evt) {
      const dataUrl = evt.target.result;
      state.business.logo = dataUrl;

      logoPreview.innerHTML = `<img src="${dataUrl}" alt="Logo Preview" style="max-height:100px;">`;
      ticketLogoImg.src = dataUrl;
      ticketLogoImg.classList.remove('hidden');
      btnRemoveLogo.classList.remove('hidden');

      showToast('Logo cargado.', 'success');
    };
    reader.readAsDataURL(file);
  }

  function handleLogoRemove() {
    state.business.logo = null;
    inputLogo.value = '';
    logoPreview.innerHTML = `<i class="fa-solid fa-cloud-arrow-up"></i><span>Subir Logo</span>`;
    ticketLogoImg.src = '';
    ticketLogoImg.classList.add('hidden');
    btnRemoveLogo.classList.add('hidden');
  }

  // --- PRODUCT CATALOG MANAGEMENT ---
  function loadProductsFromStorage() {
    fetch(`${API_BASE_URL}/productos`)
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) {
          state.productsCatalog = data;
          localStorage.setItem('martk_products', JSON.stringify(data));
          renderProductsTable();
        }
      }).catch(e => {
        try {
          const saved = localStorage.getItem('martk_products');
          if (saved) state.productsCatalog = JSON.parse(saved);
          renderProductsTable();
        } catch(err) {}
      });
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
      tr.innerHTML = `
        <td><strong>${escapeHtml(p.codigo || '-')}</strong></td>
        <td>${escapeHtml(p.nombre)}</td>
        <td><strong style="color:#4F46E5;">$${parseFloat(p.precio_usd).toFixed(2)} USD</strong></td>
        <td>${p.iva_porcentaje}%</td>
        <td><small>${escapeHtml(p.subtexto || '-')}</small></td>
        <td>
          <button class="btn btn-sm btn-primary btn-add-prod-to-pos" data-id="${p.id}"><i class="fa-solid fa-cart-plus"></i> Usar en POS</button>
          <button class="btn btn-sm btn-danger-outline btn-del-prod" data-id="${p.id}"><i class="fa-solid fa-trash"></i></button>
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
        localStorage.setItem('martk_products', JSON.stringify(state.productsCatalog));
        fetch(`${API_BASE_URL}/productos/${id}`, { method: 'DELETE' }).catch(e => {});
        renderProductsTable();
        showToast('Producto eliminado.', 'info');
      });
    });
  }

  function handleSaveProduct(e) {
    e.preventDefault();
    const idVal = document.getElementById('prod-id').value;
    const codigo = document.getElementById('prod-code').value || `PRD-${Date.now().toString().slice(-4)}`;
    const nombre = document.getElementById('prod-name').value;
    const precio_usd = parseFloat(document.getElementById('prod-price').value) || 0;
    const iva_porcentaje = parseFloat(document.getElementById('prod-tax').value) || 16;
    const subtexto = document.getElementById('prod-subtext').value || '';

    const prodObj = {
      id: idVal ? parseInt(idVal) : undefined,
      codigo,
      nombre,
      precio_usd,
      iva_porcentaje,
      subtexto
    };

    // Actualización inmediata local
    if (idVal) {
      const idx = state.productsCatalog.findIndex(p => String(p.id) === String(idVal));
      if (idx !== -1) state.productsCatalog[idx] = { ...state.productsCatalog[idx], ...prodObj };
    } else {
      state.productsCatalog.unshift({ id: Date.now(), ...prodObj });
    }

    localStorage.setItem('martk_products', JSON.stringify(state.productsCatalog));
    renderProductsTable();
    productFormBox.classList.add('hidden');
    formProduct.reset();
    showToast('Producto guardado correctamente', 'success');

    // Envío asíncrono a base de datos
    fetch(`${API_BASE_URL}/productos`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(prodObj)
    })
    .then(res => res.json())
    .then(() => {
      loadProductsFromStorage();
    })
    .catch(e => {});
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
        <small style="color:#64748B;">IVA ${p.iva_porcentaje}% ${p.subtexto ? '• ' + escapeHtml(p.subtexto) : ''}</small>
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
      taxRate: product.iva_porcentaje || 16,
      unitPrice: product.precio_usd || 0
    });

    renderItemsList();
    updateCalculationsAndPreview();
    showToast(`Agregado a la factura: ${product.nombre}`, 'success');
  }

  // --- CLIENT CATALOG MANAGEMENT ---
  function loadClientsFromStorage() {
    fetch(`${API_BASE_URL}/clientes`)
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) {
          state.clientsCatalog = data;
          localStorage.setItem('martk_clients', JSON.stringify(data));
          renderClientsTable();
        }
      }).catch(e => {
        try {
          const saved = localStorage.getItem('martk_clients');
          if (saved) state.clientsCatalog = JSON.parse(saved);
          renderClientsTable();
        } catch(err) {}
      });
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
      clientsTableBody.innerHTML = `<tr><td colspan="5" style="text-align:center; padding:1.5rem; color:#94A3B8;">No hay clientes en el directorio.</td></tr>`;
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
  }

  function handleSaveClient(e) {
    e.preventDefault();
    const identificacion = document.getElementById('c-doc').value;
    const nombre = document.getElementById('c-name').value;
    const telefono = document.getElementById('c-phone').value || '';
    const direccion = document.getElementById('c-address').value || '';

    const clientObj = { identificacion, nombre, telefono, direccion };

    // Actualización inmediata local
    const existingIdx = state.clientsCatalog.findIndex(c => c.identificacion === identificacion);
    if (existingIdx !== -1) {
      state.clientsCatalog[existingIdx] = { ...state.clientsCatalog[existingIdx], ...clientObj };
    } else {
      state.clientsCatalog.unshift({ id: Date.now(), ...clientObj });
    }

    localStorage.setItem('martk_clients', JSON.stringify(state.clientsCatalog));
    renderClientsTable();
    clientFormBox.classList.add('hidden');
    formClient.reset();
    showToast('Cliente guardado correctamente', 'success');

    fetch(`${API_BASE_URL}/clientes`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(clientObj)
    })
    .then(res => res.json())
    .then(() => {
      loadClientsFromStorage();
    })
    .catch(e => {});
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

  // --- SAVE ALL SETTINGS PERMANENTLY ---
  function saveAllSettingsPermanently() {
    state.business.name = inputBizName.value;
    state.business.id = inputBizId.value;
    state.business.phone = inputBizPhone.value;
    state.business.address = inputBizAddress.value;
    state.options.notes = inputFooterNotes.value;

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
      suiche: state.suiche,
      options: state.options
    };

    localStorage.setItem('martk_settings_permanent', JSON.stringify(settingsObj));
    showToast('Ajustes guardados correctamente', 'success');

    fetch(`${API_BASE_URL}/empresa`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        nombre: state.business.name,
        identificacion: state.business.id,
        direccion: state.business.address,
        telefono: state.business.phone,
        doc_titulo: state.business.docTitle,
        moneda: state.business.currency,
        tasa_cambio: state.exchange.rate,
        mostrar_doble_moneda: state.exchange.showDual,
        logo_base64: state.business.logo,
        logo_size: state.options.logoSize,
        show_qr: state.options.showQR,
        show_barcode: state.options.showBarcode,
        show_signature: state.options.showSignature,
        show_tax_table: state.options.showTaxTable,
        theme: state.options.theme,
        notas_pie: state.options.notes
      })
    }).catch(e => {});

    updateCalculationsAndPreview();
  }

  function loadSavedSettingsAndBusiness() {
    fetch(`${API_BASE_URL}/empresa`)
      .then(res => res.json())
      .then(parsed => {
        if (parsed) {
          if (parsed.nombre) state.business.name = parsed.nombre;
          if (parsed.identificacion) state.business.id = parsed.identificacion;
          if (parsed.telefono) state.business.phone = parsed.telefono;
          if (parsed.direccion) state.business.address = parsed.direccion;
          if (parsed.logo_base64) state.business.logo = parsed.logo_base64;
          if (parsed.logo_size) state.options.logoSize = parsed.logo_size;
          
          if (typeof parsed.show_qr !== 'undefined') state.options.showQR = !!parsed.show_qr;
          if (typeof parsed.show_barcode !== 'undefined') state.options.showBarcode = !!parsed.show_barcode;
          if (typeof parsed.show_signature !== 'undefined') state.options.showSignature = !!parsed.show_signature;
          if (typeof parsed.show_tax_table !== 'undefined') state.options.showTaxTable = !!parsed.show_tax_table;
          if (parsed.theme) state.options.theme = parsed.theme;
          if (parsed.notas_pie) state.options.notes = parsed.notas_pie;

          inputBizName.value = state.business.name || '';
          inputBizId.value = state.business.id || '';
          inputBizPhone.value = state.business.phone || '';
          inputBizAddress.value = state.business.address || '';
          inputFooterNotes.value = state.options.notes || '';
          
          logoSizeRange.value = state.options.logoSize || 220;
          logoSizeVal.textContent = `${state.options.logoSize || 220} px`;

          prefShowQr.checked = state.options.showQR;
          prefShowBarcode.checked = state.options.showBarcode;
          prefShowSignature.checked = state.options.showSignature;
          prefShowTaxTable.checked = state.options.showTaxTable;

          themeCards.forEach(card => {
            if (card.getAttribute('data-theme') === state.options.theme) {
              themeCards.forEach(c => c.classList.remove('active'));
              card.classList.add('active');
              ticketCard.className = `ticket-card ${state.options.theme}`;
            }
          });
          
          if (state.business.logo) {
            logoPreview.innerHTML = `<img src="${state.business.logo}" alt="Logo" style="max-height:100px;">`;
            ticketLogoImg.src = state.business.logo;
            ticketLogoImg.classList.remove('hidden');
            btnRemoveLogo.classList.remove('hidden');
          }
          updateCalculationsAndPreview();
        }
      }).catch(e => {
        try {
          const saved = localStorage.getItem('martk_settings_permanent');
          if (saved) {
            const parsed = JSON.parse(saved);
            if (parsed.business) state.business = parsed.business;
            if (parsed.suiche) state.suiche = parsed.suiche;
            if (parsed.options) state.options = parsed.options;
          }
        } catch(err) {}
      });
  }

  // --- SAVE RECEIPT TO HISTORY ---
  async function saveCurrentReceiptToHistory() {
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
      target_currency: state.exchange.targetCurrency,
      suiche_bank: state.suiche.bank,
      suiche_doc: `${state.suiche.docType}${state.suiche.docNumber}`,
      suiche_phone: state.suiche.phone,
      items: JSON.parse(JSON.stringify(state.items))
    };

    state.history.unshift(receiptRecord);
    saveHistoryToStorage();

    try {
      await fetch(`${API_BASE_URL}/comprobantes`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(receiptRecord)
      });
      loadClientsFromStorage();
    } catch (e) {}

    incrementFolioCounter();
    updateCalculationsAndPreview();

    showToast(`Comprobante guardado. Próximo folio: ${state.business.docNumber}`, 'success');
  }

  function incrementFolioCounter() {
    state.folioCounter++;
    state.business.docNumber = formatFolioNumber(state.folioCounter);
    if (posDocNumber) posDocNumber.textContent = state.business.docNumber;
    if (inputDocNumber) inputDocNumber.value = state.business.docNumber;
    if (inputFolioCounter) inputFolioCounter.value = state.folioCounter;
    localStorage.setItem('martk_folio_counter', state.folioCounter.toString());
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
        fetch(`${API_BASE_URL}/comprobantes/${uuid}`, { method: 'DELETE' }).catch(e => {});
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
    localStorage.setItem('martk_history_records', JSON.stringify(state.history));
    if (sidebarHistoryCount) sidebarHistoryCount.textContent = state.history.length;
  }

  function loadHistoryFromStorage() {
    fetch(`${API_BASE_URL}/comprobantes`)
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) {
          state.history = data;
          saveHistoryToStorage();
        }
      }).catch(e => {
        try {
          const savedHist = localStorage.getItem('martk_history_records');
          if (savedHist) {
            state.history = JSON.parse(savedHist);
            if (sidebarHistoryCount) sidebarHistoryCount.textContent = state.history.length;
          }
        } catch(err) {}
      });

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

      fetch(`${API_BASE_URL}/admin/clear-db`, { method: 'DELETE' }).catch(e => {});
      showToast('Historial limpio.', 'info');
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
      msg += `*EQUIVALENTE BS (BCV):* ${fmtBs(state.totals.grandTotal * rate)}\n`;
      msg += `*Tasa Ref BCV (USD):* 1 USD = ${rate.toFixed(2)} Bs.\n`;
    } else {
      msg += `-----------------------------------\n`;
      msg += `*Concepto:* ${state.paymentDetails.concept}\n`;
      msg += `*MONTO: ${fmtInputCurr(state.paymentDetails.amount)} USD*\n`;
      msg += `*EQUIVALENTE BS (BCV):* ${fmtBs(state.paymentDetails.amount * rate)}\n`;
    }

    if (state.suiche.phone && state.suiche.docNumber) {
      msg += `-----------------------------------\n`;
      msg += `*PAGO MÓVIL SUICHE 7B:*\n`;
      msg += `*Banco:* ${state.suiche.bank} | RIF: ${state.suiche.docType}${state.suiche.docNumber} | Tel: ${state.suiche.phone}\n`;
      msg += `*Monto a Transferir:* ${fmtBs(state.totals.grandTotal * rate)}\n`;
    }

    msg += `\nDocumento generado con MARTK POS`;

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
      { id: '101', cant: 1, desc: 'LICENCIA MARTK POS ADMIN V2.0', subtext: 'Suscripción Anual', taxRate: 16, unitPrice: 50.00 },
      { id: '102', cant: 2, desc: 'IMPRESORA TÉRMICA BLUETOOTH 80MM', subtext: 'Garantía 12 meses', taxRate: 16, unitPrice: 45.00 }
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
      { id: Date.now().toString(), cant: 1, desc: '', subtext: '', taxRate: 16, unitPrice: 0 }
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

  // Launch App
  init();
});
