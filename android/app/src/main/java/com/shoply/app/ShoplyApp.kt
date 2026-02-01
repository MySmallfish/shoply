package com.shoply.app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.util.Base64
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Group
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.PowerSettingsNew
import androidx.compose.material.ExperimentalMaterialApi
import androidx.compose.material.pullrefresh.PullRefreshIndicator
import androidx.compose.material.pullrefresh.pullRefresh
import androidx.compose.material.pullrefresh.rememberPullRefreshState
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Divider
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarDuration
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.SnackbarResult
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.res.stringResource
import androidx.compose.material3.LocalTextStyle
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import java.io.ByteArrayOutputStream
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun ShoplyApp(viewModel: MainViewModel) {
    val user by viewModel.user.collectAsState(initial = null)
    if (user == null) {
        SignInScreen(viewModel)
    } else {
        ListScreen(viewModel)
    }
}

@Composable
fun SignInScreen(viewModel: MainViewModel) {
    val context = LocalContext.current
    val activity = context as? Activity

    val gso = remember {
        GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
            .requestIdToken(context.getString(R.string.default_web_client_id))
            .requestEmail()
            .build()
    }
    val googleClient = remember { GoogleSignIn.getClient(context, gso) }

    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val task = GoogleSignIn.getSignedInAccountFromIntent(result.data)
        try {
            val account = task.getResult(ApiException::class.java)
            handleGoogleSignIn(account, viewModel)
        } catch (_: Exception) {
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = stringResource(R.string.app_name),
            fontSize = 36.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = stringResource(R.string.sign_in_subtitle),
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
        )
        Spacer(modifier = Modifier.height(32.dp))

        Button(
            onClick = { if (activity != null) launcher.launch(googleClient.signInIntent) },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(stringResource(R.string.continue_with_google))
        }
    }
}

private fun handleGoogleSignIn(account: GoogleSignInAccount?, viewModel: MainViewModel) {
    val idToken = account?.idToken ?: return
    viewModel.signInWithGoogle(idToken)
}

@OptIn(ExperimentalMaterial3Api::class, ExperimentalMaterialApi::class)
@Composable
fun ListScreen(viewModel: MainViewModel) {
    val lists by viewModel.lists.collectAsState(initial = emptyList())
    val items by viewModel.items.collectAsState(initial = emptyList())
    val catalogItems by viewModel.catalogItems.collectAsState(initial = emptyList())
    val members by viewModel.members.collectAsState(initial = emptyList())
    val invites by viewModel.invites.collectAsState(initial = emptyList())
    val pendingInvites by viewModel.pendingInvites.collectAsState(initial = emptyList())
    val inviteActionError by viewModel.inviteActionError.collectAsState(initial = null)
    val mergePrompt by viewModel.mergePrompt.collectAsState(initial = null)
    val currentRole by viewModel.currentRole.collectAsState(initial = null)
    val selectedListId by viewModel.selectedListId.collectAsState(initial = null)
    val undoAction by viewModel.undoAction.collectAsState(initial = null)
    val context = LocalContext.current

    var newItemName by remember { mutableStateOf("") }
    var showInvite by remember { mutableStateOf(false) }
    var showCreateList by remember { mutableStateOf(false) }
    var showScanner by remember { mutableStateOf(false) }
    var showJoin by remember { mutableStateOf(false) }
    var showMembers by remember { mutableStateOf(false) }
    var showPendingInvites by remember { mutableStateOf(false) }
    var showAddFromScan by remember { mutableStateOf(false) }
    var scanCode by remember { mutableStateOf<String?>(null) }
    var scannedDraft by remember { mutableStateOf(ItemDetailsDraft()) }
    var adjustItem by remember { mutableStateOf<ShoppingItem?>(null) }
    var adjustMode by remember { mutableStateOf(QuantityMode.BOUGHT) }
    var adjustAmount by remember { mutableStateOf(1) }
    var selectedSuggestion by remember { mutableStateOf<CatalogItem?>(null) }
    var showDetails by remember { mutableStateOf(false) }
    var detailsDraft by remember { mutableStateOf(ItemDetailsDraft()) }
    var detailsAllowBarcodeEdit by remember { mutableStateOf(true) }
    var isRefreshing by remember { mutableStateOf(false) }
    val snackbarHostState = remember { SnackbarHostState() }
    val refreshScope = rememberCoroutineScope()
    val pullRefreshState = rememberPullRefreshState(
        refreshing = isRefreshing,
        onRefresh = {
            refreshScope.launch {
                isRefreshing = true
                viewModel.refreshSelectedList()
                delay(350)
                isRefreshing = false
            }
        }
    )

    fun openAdjustDialog(item: ShoppingItem) {
        val defaultMode = if (item.quantity <= 0) QuantityMode.NEED else QuantityMode.BOUGHT
        val defaultAmount = if (defaultMode == QuantityMode.BOUGHT) maxOf(1, item.quantity) else 1
        adjustItem = item
        adjustMode = defaultMode
        adjustAmount = defaultAmount
    }

    LaunchedEffect(scanCode) {
        val code = scanCode ?: return@LaunchedEffect
        newItemName = code
        selectedSuggestion = null
        val item = items.firstOrNull { it.barcode == code }
        if (item != null) {
            openAdjustDialog(item)
            scanCode = null
        } else {
            val catalogMatch = viewModel.catalogItemForBarcode(code)
            scannedDraft = ItemDetailsDraft(
                name = catalogMatch?.name.orEmpty(),
                barcode = code,
                price = catalogMatch?.price?.toString().orEmpty(),
                description = catalogMatch?.description.orEmpty(),
                icon = catalogMatch?.icon.orEmpty()
            )
            showAddFromScan = true
        }
    }

    LaunchedEffect(inviteActionError) {
        val message = inviteActionError ?: return@LaunchedEffect
        Toast.makeText(context, message, Toast.LENGTH_LONG).show()
        viewModel.clearInviteActionError()
    }

    LaunchedEffect(undoAction) {
        val action = undoAction ?: return@LaunchedEffect
        val result = snackbarHostState.showSnackbar(
            message = if (action.wasBought) {
                context.getString(R.string.marked_unbought)
            } else {
                context.getString(R.string.marked_bought)
            },
            actionLabel = context.getString(R.string.undo),
            duration = SnackbarDuration.Short
        )
        if (result == SnackbarResult.ActionPerformed) {
            viewModel.undoLastToggle()
        } else {
            viewModel.clearUndo()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    ListDropdown(
                        lists = lists,
                        selectedListId = selectedListId,
                        onSelect = { viewModel.selectList(it.id) },
                        onCreate = { showCreateList = true },
                        onJoin = { showJoin = true }
                    )
                },
                actions = {
                    IconButton(onClick = { showMembers = true }) {
                        Icon(imageVector = Icons.Default.Group, contentDescription = stringResource(R.string.cd_members))
                    }
                    IconButton(onClick = { showInvite = true }) {
                        Icon(imageVector = Icons.Default.PersonAdd, contentDescription = stringResource(R.string.cd_invite))
                    }
                    IconButton(onClick = { showPendingInvites = true }) {
                        Icon(imageVector = Icons.Default.Email, contentDescription = stringResource(R.string.cd_pending_invitations))
                    }
                    IconButton(onClick = { viewModel.signOut() }) {
                        Icon(imageVector = Icons.Default.PowerSettingsNew, contentDescription = stringResource(R.string.cd_sign_out))
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        floatingActionButton = {
            FloatingActionButton(onClick = { showScanner = true }) {
                Icon(imageVector = Icons.Default.CameraAlt, contentDescription = stringResource(R.string.cd_scan))
            }
        },
        bottomBar = {
            val suggestions = remember(newItemName, catalogItems) {
                viewModel.suggestionsFor(newItemName)
            }
            Column {
                if (suggestions.isNotEmpty()) {
                    SuggestionList(
                        suggestions = suggestions,
                        onSelect = { item ->
                            newItemName = item.name
                            selectedSuggestion = item
                        }
                    )
                }
                AddItemBar(
                    text = newItemName,
                    onTextChange = { value ->
                        newItemName = value
                        if (selectedSuggestion != null && viewModel.matchingCatalogItem(value)?.id != selectedSuggestion?.id) {
                            selectedSuggestion = null
                        }
                    },
                    onAdd = {
                        val trimmed = newItemName.trim()
                        if (trimmed.isNotEmpty()) {
                            val match = selectedSuggestion ?: viewModel.matchingCatalogItem(trimmed)
                            val normalized = trimmed.lowercase()
                            val hasListMatch = items.any { it.normalizedName == normalized }
                            if (hasListMatch || match != null) {
                                viewModel.addItem(
                                    trimmed,
                                    match?.barcode,
                                    match?.price,
                                    match?.description,
                                    match?.icon
                                )
                                newItemName = ""
                                selectedSuggestion = null
                            } else {
                                scannedDraft = ItemDetailsDraft(name = trimmed)
                                scanCode = ""
                                showAddFromScan = true
                            }
                        }
                    },
                    onDetails = {
                        val trimmed = newItemName.trim()
                        val match = selectedSuggestion ?: viewModel.matchingCatalogItem(trimmed)
                        detailsDraft = ItemDetailsDraft(
                            name = if (trimmed.isNotEmpty()) trimmed else match?.name.orEmpty(),
                            barcode = match?.barcode.orEmpty(),
                            price = match?.price?.toString().orEmpty(),
                            description = match?.description.orEmpty(),
                            icon = match?.icon.orEmpty()
                        )
                        detailsAllowBarcodeEdit = match?.barcode.isNullOrBlank()
                        showDetails = true
                    }
                )
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .pullRefresh(pullRefreshState)
        ) {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp)
            ) {
                if (items.isEmpty()) {
                    item {
                        Box(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 48.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = stringResource(R.string.add_first_item),
                                color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
                            )
                        }
                    }
                } else {
                    items(items) { item ->
                        ItemRow(
                            item = item,
                            onTap = { openAdjustDialog(item) },
                            onIncrement = { viewModel.incrementQuantity(item) },
                            onDecrement = { viewModel.decrementQuantity(item) }
                        )
                    }
                }
            }

            PullRefreshIndicator(
                refreshing = isRefreshing,
                state = pullRefreshState,
                modifier = Modifier.align(Alignment.TopCenter)
            )
        }
    }

    if (showInvite) {
        InviteDialog(
            onDismiss = { showInvite = false },
            onSend = { email, role ->
                val trimmed = email.trim()
                viewModel.sendInvite(
                    trimmed,
                    role,
                    onInviteCreated = { token ->
                        val inviteUrl = "https://shoply.simplevision.co.il/invite/$token"
                        val shareIntent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, inviteUrl)
                        }
                        context.startActivity(
                            Intent.createChooser(
                                shareIntent,
                                context.getString(R.string.share_invite_link)
                            )
                        )
                        showInvite = false
                    },
                    onError = { message ->
                        Toast.makeText(context, message, Toast.LENGTH_LONG).show()
                    }
                )
            }
        )
    }

    if (showMembers) {
        MembersDialog(
            members = members,
            invites = invites,
            currentRole = currentRole,
            onDismiss = { showMembers = false },
            onRoleChange = { memberId, role -> viewModel.updateMemberRole(memberId, role) },
            onRemove = { memberId -> viewModel.removeMember(memberId) },
            onRevoke = { inviteId -> viewModel.revokeInvite(inviteId) }
        )
    }

    if (showPendingInvites) {
        PendingInvitesDialog(
            invites = pendingInvites,
            onDismiss = { showPendingInvites = false },
            onAccept = { token -> viewModel.handleInviteToken(token) }
        )
    }

    mergePrompt?.let { prompt ->
        AlertDialog(
            onDismissRequest = { viewModel.dismissMergePrompt() },
            title = { Text(stringResource(R.string.merge_lists_title)) },
            text = {
                Text(
                    stringResource(
                        R.string.merge_prompt_message,
                        prompt.existingListTitle,
                        prompt.invitedListTitle
                    )
                )
            },
            confirmButton = {
                TextButton(onClick = { viewModel.mergeInvitedList(prompt) }) {
                    Text(stringResource(R.string.merge))
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.keepInviteSeparate(prompt) }) {
                    Text(stringResource(R.string.keep_separate))
                }
            }
        )
    }

    if (showCreateList) {
        CreateListDialog(
            onDismiss = { showCreateList = false },
            onCreate = { title ->
                viewModel.createList(title)
                showCreateList = false
            }
        )
    }

    if (showScanner) {
        ScannerDialog(
            onDismiss = { showScanner = false },
            onCode = { code ->
                scanCode = code
                showScanner = false
            }
        )
    }

    if (showJoin) {
        JoinListDialog(
            onDismiss = { showJoin = false },
            onJoin = { token ->
                viewModel.handleInviteToken(token)
                showJoin = false
            }
        )
    }

    adjustItem?.let { item ->
        AdjustQuantityDialog(
            item = item,
            mode = adjustMode,
            amount = adjustAmount,
            onModeChange = { adjustMode = it },
            onAmountChange = { adjustAmount = it },
            onDismiss = { adjustItem = null },
            onApply = {
                val resolved = maxOf(1, adjustAmount)
                val delta = if (adjustMode == QuantityMode.BOUGHT) -resolved else resolved
                viewModel.adjustQuantity(item, delta)
                adjustItem = null
            }
        )
    }

    if (showAddFromScan) {
        AddScannedItemDialog(
            barcode = scanCode ?: "",
            draft = scannedDraft,
            onDraftChange = { scannedDraft = it },
            onDismiss = {
                showAddFromScan = false
                scanCode = null
            },
            onAdd = {
                viewModel.addItem(
                    scannedDraft.name,
                    scannedDraft.barcode.ifBlank { null },
                    scannedDraft.priceValue(),
                    scannedDraft.description,
                    scannedDraft.icon
                )
                scannedDraft = ItemDetailsDraft()
                showAddFromScan = false
                scanCode = null
            }
        )
    }

    if (showDetails) {
        ItemDetailsDialog(
            draft = detailsDraft,
            onDraftChange = { detailsDraft = it },
            onDismiss = { showDetails = false },
            allowBarcodeEdit = detailsAllowBarcodeEdit,
            onSave = {
                viewModel.addItem(
                    detailsDraft.name,
                    detailsDraft.barcode.ifBlank { null },
                    detailsDraft.priceValue(),
                    detailsDraft.description,
                    detailsDraft.icon
                )
                newItemName = ""
                selectedSuggestion = null
                showDetails = false
                detailsDraft = ItemDetailsDraft()
            }
        )
    }
}

@Composable
private fun ItemRow(
    item: ShoppingItem,
    onTap: () -> Unit,
    onIncrement: () -> Unit,
    onDecrement: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(
            modifier = Modifier
                .weight(1f)
                .clickable { onTap() },
            verticalAlignment = Alignment.CenterVertically
        ) {
            item.icon?.takeIf { it.isNotBlank() }?.let { icon ->
                ItemIconView(
                    icon = icon,
                    size = 20.dp,
                    modifier = Modifier.padding(end = 6.dp)
                )
            }
            Text(
                text = item.name,
                color = MaterialTheme.colorScheme.onBackground
            )
        }
        IconButton(onClick = onDecrement) {
            Icon(imageVector = Icons.Default.Remove, contentDescription = stringResource(R.string.decrease))
        }
        Text(
            text = item.quantity.toString(),
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.widthIn(min = 20.dp)
        )
        IconButton(onClick = onIncrement) {
            Icon(imageVector = Icons.Default.Add, contentDescription = stringResource(R.string.increase))
        }
    }
}

@Composable
private fun AddItemBar(
    text: String,
    onTextChange: (String) -> Unit,
    onAdd: () -> Unit,
    onDetails: () -> Unit
) {
    val keyboardController = LocalSoftwareKeyboardController.current
    val canAdd = text.trim().isNotEmpty()
    val textAlign = inputTextAlign()
    val textStyle = LocalTextStyle.current.copy(textAlign = textAlign)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TextField(
            value = text,
            onValueChange = onTextChange,
            modifier = Modifier.weight(1f),
            placeholder = { PlaceholderText(stringResource(R.string.add_item_placeholder), textAlign) },
            textStyle = textStyle,
            singleLine = true,
            keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
            keyboardActions = KeyboardActions(
                onDone = {
                    if (canAdd) {
                        onAdd()
                        keyboardController?.hide()
                    }
                }
            )
        )
        Spacer(modifier = Modifier.size(12.dp))
        IconButton(onClick = onDetails, enabled = canAdd) {
            Icon(imageVector = Icons.Default.Edit, contentDescription = stringResource(R.string.details))
        }
        Spacer(modifier = Modifier.size(6.dp))
        Button(
            onClick = onAdd,
            enabled = canAdd,
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.primary)
        ) {
            Icon(imageVector = Icons.Default.Add, contentDescription = null)
        }
    }
}

@Composable
private fun ListDropdown(
    lists: List<ShoppingList>,
    selectedListId: String?,
    onSelect: (ShoppingList) -> Unit,
    onCreate: () -> Unit,
    onJoin: () -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val currentTitle = lists.firstOrNull { it.id == selectedListId }?.title
        ?: stringResource(R.string.lists)

    Box {
        TextButton(onClick = { expanded = true }) {
            Text(currentTitle, fontWeight = FontWeight.SemiBold)
            Icon(imageVector = Icons.Default.ArrowDropDown, contentDescription = null)
        }
        androidx.compose.material3.DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            lists.forEach { list ->
                androidx.compose.material3.DropdownMenuItem(
                    text = { Text(list.title) },
                    onClick = {
                        expanded = false
                        onSelect(list)
                    }
                )
            }
            Divider()
            androidx.compose.material3.DropdownMenuItem(
                text = { Text(stringResource(R.string.new_list)) },
                onClick = {
                    expanded = false
                    onCreate()
                }
            )
            androidx.compose.material3.DropdownMenuItem(
                text = { Text(stringResource(R.string.join_with_link)) },
                onClick = {
                    expanded = false
                    onJoin()
                }
            )
        }
    }
}

@Composable
private fun InviteDialog(onDismiss: () -> Unit, onSend: (String, String) -> Unit) {
    var email by remember { mutableStateOf("") }
    var role by remember { mutableStateOf("editor") }
    var roleExpanded by remember { mutableStateOf(false) }
    val textAlign = inputTextAlign()
    val textStyle = LocalTextStyle.current.copy(textAlign = textAlign)
    val roleLabel = when (role) {
        "owner" -> stringResource(R.string.role_owner)
        "viewer" -> stringResource(R.string.role_viewer)
        else -> stringResource(R.string.role_editor)
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.invite_title)) },
        text = {
            Column {
                TextField(
                    value = email,
                    onValueChange = { email = it },
                    placeholder = { PlaceholderText(stringResource(R.string.email), textAlign) },
                    textStyle = textStyle
                )
                Spacer(modifier = Modifier.height(12.dp))
                Box {
                    TextButton(onClick = { roleExpanded = true }) {
                        Text(stringResource(R.string.role_label_format, roleLabel))
                    }
                    androidx.compose.material3.DropdownMenu(
                        expanded = roleExpanded,
                        onDismissRequest = { roleExpanded = false }
                    ) {
                        androidx.compose.material3.DropdownMenuItem(
                            text = { Text(stringResource(R.string.role_editor)) },
                            onClick = { role = "editor"; roleExpanded = false }
                        )
                        androidx.compose.material3.DropdownMenuItem(
                            text = { Text(stringResource(R.string.role_viewer)) },
                            onClick = { role = "viewer"; roleExpanded = false }
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = { onSend(email, role) }, enabled = email.trim().isNotEmpty()) {
                Text(stringResource(R.string.send))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun CreateListDialog(onDismiss: () -> Unit, onCreate: (String) -> Unit) {
    var title by remember { mutableStateOf("") }
    val textAlign = inputTextAlign()
    val textStyle = LocalTextStyle.current.copy(textAlign = textAlign)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.new_list)) },
        text = {
            TextField(
                value = title,
                onValueChange = { title = it },
                placeholder = { PlaceholderText(stringResource(R.string.list_name_placeholder), textAlign) },
                textStyle = textStyle
            )
        },
        confirmButton = {
            Button(onClick = { onCreate(title) }, enabled = title.trim().isNotEmpty()) {
                Text(stringResource(R.string.create))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun MembersDialog(
    members: List<MemberViewData>,
    invites: List<InviteViewData>,
    currentRole: String?,
    onDismiss: () -> Unit,
    onRoleChange: (String, String) -> Unit,
    onRemove: (String) -> Unit,
    onRevoke: (String) -> Unit
) {
    val isOwner = currentRole == "owner"

    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = MaterialTheme.shapes.medium,
            color = MaterialTheme.colorScheme.surface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp)
            ) {
                Text(stringResource(R.string.members_title), style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(12.dp))

                if (members.isEmpty()) {
                    Text(
                        stringResource(R.string.no_members_found),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                } else {
                    LazyColumn(
                        modifier = Modifier.heightIn(max = 360.dp)
                    ) {
                        items(members) { member ->
                            MemberRow(
                                member = member,
                                isOwner = isOwner,
                                onRoleChange = { role -> onRoleChange(member.id, role) },
                                onRemove = { onRemove(member.id) }
                            )
                        }
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                if (isOwner) {
                    Text(stringResource(R.string.invites_title), style = MaterialTheme.typography.titleLarge)
                    Spacer(modifier = Modifier.height(8.dp))
                    if (invites.isEmpty()) {
                        Text(
                            stringResource(R.string.no_pending_invites),
                            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                        )
                    } else {
                        Column {
                            invites.forEach { invite ->
                                InviteRow(invite = invite, onRevoke = { onRevoke(invite.id) })
                            }
                        }
                    }
                } else {
                    Text(
                        stringResource(R.string.only_owner_manage),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text(stringResource(R.string.done))
                    }
                }
            }
        }
    }
}

@Composable
private fun PendingInvitesDialog(
    invites: List<PendingInvite>,
    onDismiss: () -> Unit,
    onAccept: (String) -> Unit
) {
    Dialog(onDismissRequest = onDismiss) {
        Surface(
            shape = MaterialTheme.shapes.medium,
            color = MaterialTheme.colorScheme.surface
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp)
            ) {
                Text(stringResource(R.string.pending_invitations_title), style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(12.dp))

                if (invites.isEmpty()) {
                    Text(
                        stringResource(R.string.no_pending_invitations),
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                } else {
                    LazyColumn(
                        modifier = Modifier.heightIn(max = 360.dp)
                    ) {
                        items(invites) { invite ->
                            PendingInviteRow(invite = invite, onAccept = { onAccept(invite.token) })
                        }
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text(stringResource(R.string.done))
                    }
                }
            }
        }
    }
}

@Composable
private fun PendingInviteRow(invite: PendingInvite, onAccept: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            val title = if (invite.listTitle.isBlank()) {
                stringResource(R.string.shoply_list_title)
            } else {
                invite.listTitle
            }
            Text(title, fontWeight = FontWeight.SemiBold)
            Text(
                roleLabel(invite.role),
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }

        Button(onClick = onAccept) {
            Text(stringResource(R.string.accept))
        }
    }
}

@Composable
private fun MemberRow(
    member: MemberViewData,
    isOwner: Boolean,
    onRoleChange: (String) -> Unit,
    onRemove: () -> Unit
) {
    var menuOpen by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(member.name, fontWeight = FontWeight.SemiBold)
                if (member.isCurrentUser) {
                    Spacer(modifier = Modifier.size(6.dp))
                    Text(
                        stringResource(R.string.you),
                        fontSize = 12.sp,
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }
            }
            if (member.email.isNotEmpty()) {
                Text(member.email, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
            }
        }

        Text(
            roleLabel(member.role),
            fontSize = 12.sp,
            color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.7f),
            modifier = Modifier.padding(end = 8.dp)
        )

        if (isOwner && !member.isCurrentUser && member.role != "owner") {
            Box {
                IconButton(onClick = { menuOpen = true }) {
                    Icon(imageVector = Icons.Default.MoreVert, contentDescription = stringResource(R.string.cd_manage_member))
                }
                androidx.compose.material3.DropdownMenu(
                    expanded = menuOpen,
                    onDismissRequest = { menuOpen = false }
                ) {
                    androidx.compose.material3.DropdownMenuItem(
                        text = { Text(stringResource(R.string.make_editor)) },
                        onClick = {
                            menuOpen = false
                            onRoleChange("editor")
                        }
                    )
                    androidx.compose.material3.DropdownMenuItem(
                        text = { Text(stringResource(R.string.make_viewer)) },
                        onClick = {
                            menuOpen = false
                            onRoleChange("viewer")
                        }
                    )
                    Divider()
                    androidx.compose.material3.DropdownMenuItem(
                        text = { Text(stringResource(R.string.remove)) },
                        onClick = {
                            menuOpen = false
                            onRemove()
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun InviteRow(invite: InviteViewData, onRevoke: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(invite.email, fontWeight = FontWeight.SemiBold)
            Text(
                "${roleLabel(invite.role)} • ${statusLabel(invite.status)}",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }

        if (invite.status == "pending") {
            TextButton(onClick = onRevoke) {
                Text(stringResource(R.string.revoke))
            }
        }
    }
}

@Composable
private fun roleLabel(role: String): String {
    return when (role) {
        "owner" -> stringResource(R.string.role_owner)
        "viewer" -> stringResource(R.string.role_viewer)
        else -> stringResource(R.string.role_editor)
    }
}

@Composable
private fun statusLabel(status: String): String {
    return when (status) {
        "accepted" -> stringResource(R.string.status_accepted)
        "revoked" -> stringResource(R.string.status_revoked)
        else -> stringResource(R.string.status_pending)
    }
}

@Composable
private fun JoinListDialog(onDismiss: () -> Unit, onJoin: (String) -> Unit) {
    var input by remember { mutableStateOf("") }
    val token = extractToken(input)
    val textAlign = inputTextAlign()
    val textStyle = LocalTextStyle.current.copy(textAlign = textAlign)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.join_list_title)) },
        text = {
            TextField(
                value = input,
                onValueChange = { input = it },
                placeholder = { PlaceholderText(stringResource(R.string.paste_invite_link), textAlign) },
                textStyle = textStyle
            )
        },
        confirmButton = {
            Button(onClick = { token?.let(onJoin) }, enabled = !token.isNullOrBlank()) {
                Text(stringResource(R.string.join))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

private fun extractToken(input: String): String? {
    val trimmed = input.trim()
    if (trimmed.isEmpty()) return null
    return try {
        val uri = Uri.parse(trimmed)
        val token = uri.getQueryParameter("token")
        if (!token.isNullOrBlank()) {
            token
        } else {
            val segments = uri.pathSegments
            val inviteIndex = segments.indexOf("invite")
            if (inviteIndex != -1 && segments.size > inviteIndex + 1) {
                segments[inviteIndex + 1]
            } else {
                trimmed
            }
        }
    } catch (_: Exception) {
        trimmed
    }
}

private data class ItemDetailsDraft(
    val name: String = "",
    val barcode: String = "",
    val price: String = "",
    val description: String = "",
    val icon: String = ""
) {
    fun priceValue(): Double? {
        val trimmed = price.trim()
        if (trimmed.isEmpty()) return null
        return trimmed.replace(",", ".").toDoubleOrNull()
    }
}

@Composable
private fun SuggestionList(
    suggestions: List<CatalogItem>,
    onSelect: (CatalogItem) -> Unit
) {
    Surface(shadowElevation = 2.dp) {
        Column(modifier = Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
            suggestions.forEach { item ->
                TextButton(onClick = { onSelect(item) }, modifier = Modifier.fillMaxWidth()) {
                    Row(modifier = Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        item.icon?.takeIf { it.isNotBlank() }?.let { icon ->
                            ItemIconView(icon = icon, size = 18.dp)
                            Spacer(modifier = Modifier.width(8.dp))
                        }
                        Text(text = item.name, modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun ItemDetailsDialog(
    draft: ItemDetailsDraft,
    onDraftChange: (ItemDetailsDraft) -> Unit,
    onDismiss: () -> Unit,
    allowBarcodeEdit: Boolean,
    onSave: () -> Unit
) {
    val textAlign = inputTextAlign()
    val textStyle = LocalTextStyle.current.copy(textAlign = textAlign)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.item_details)) },
        text = {
            Column {
                TextField(
                    value = draft.name,
                    onValueChange = { onDraftChange(draft.copy(name = it)) },
                    placeholder = { PlaceholderText(stringResource(R.string.name), textAlign) },
                    textStyle = textStyle
                )
                Spacer(modifier = Modifier.height(8.dp))
                BarcodeField(
                    value = draft.barcode,
                    onValueChange = { onDraftChange(draft.copy(barcode = it)) },
                    textAlign = textAlign,
                    initiallyEditable = allowBarcodeEdit
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.price,
                    onValueChange = { onDraftChange(draft.copy(price = it)) },
                    placeholder = { PlaceholderText(stringResource(R.string.price), textAlign) },
                    textStyle = textStyle
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.description,
                    onValueChange = { onDraftChange(draft.copy(description = it)) },
                    placeholder = { PlaceholderText(stringResource(R.string.description), textAlign) },
                    textStyle = textStyle
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = stringResource(R.string.icon),
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = textAlign,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.height(6.dp))
                IconPicker(
                    icon = draft.icon,
                    onIconChange = { onDraftChange(draft.copy(icon = it)) }
                )
            }
        },
        confirmButton = {
            Button(onClick = onSave, enabled = draft.name.trim().isNotEmpty()) {
                Text(stringResource(R.string.save))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun AdjustQuantityDialog(
    item: ShoppingItem,
    mode: QuantityMode,
    amount: Int,
    onModeChange: (QuantityMode) -> Unit,
    onAmountChange: (Int) -> Unit,
    onDismiss: () -> Unit,
    onApply: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.how_much_did_you_buy)) },
        text = {
            Column {
                Text(
                    stringResource(R.string.left_to_buy_format, item.quantity),
                    color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f)
                )
                Spacer(modifier = Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (mode == QuantityMode.BOUGHT) {
                        Button(onClick = { onModeChange(QuantityMode.BOUGHT) }) {
                            Text(stringResource(R.string.bought))
                        }
                        OutlinedButton(onClick = { onModeChange(QuantityMode.NEED) }) {
                            Text(stringResource(R.string.need))
                        }
                    } else {
                        OutlinedButton(onClick = { onModeChange(QuantityMode.BOUGHT) }) {
                            Text(stringResource(R.string.bought))
                        }
                        Button(onClick = { onModeChange(QuantityMode.NEED) }) {
                            Text(stringResource(R.string.need))
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(24.dp, Alignment.CenterHorizontally),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    OutlinedButton(
                        onClick = { if (amount > 1) onAmountChange(amount - 1) },
                        modifier = Modifier.size(56.dp),
                        shape = CircleShape,
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Icon(imageVector = Icons.Default.Remove, contentDescription = stringResource(R.string.decrease_amount))
                    }
                    Text(
                        text = amount.coerceAtLeast(1).toString(),
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold
                    )
                    OutlinedButton(
                        onClick = { onAmountChange(amount + 1) },
                        modifier = Modifier.size(56.dp),
                        shape = CircleShape,
                        contentPadding = PaddingValues(0.dp)
                    ) {
                        Icon(imageVector = Icons.Default.Add, contentDescription = stringResource(R.string.increase_amount))
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = onApply) {
                Text(stringResource(R.string.apply))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

private enum class QuantityMode {
    BOUGHT,
    NEED
}


@Composable
private fun AddScannedItemDialog(
    barcode: String,
    draft: ItemDetailsDraft,
    onDraftChange: (ItemDetailsDraft) -> Unit,
    onDismiss: () -> Unit,
    onAdd: () -> Unit
) {
    val textAlign = inputTextAlign()
    val textStyle = LocalTextStyle.current.copy(textAlign = textAlign)
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.add_item_title)) },
        text = {
            Column {
                if (barcode.isNotBlank()) {
                    Text(
                        stringResource(R.string.scanned_format, barcode),
                        fontWeight = FontWeight.SemiBold
                    )
                    Spacer(modifier = Modifier.height(8.dp))
                }
                BarcodeField(
                    value = draft.barcode,
                    onValueChange = { onDraftChange(draft.copy(barcode = it)) },
                    textAlign = textAlign,
                    initiallyEditable = barcode.isBlank()
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.name,
                    onValueChange = { onDraftChange(draft.copy(name = it)) },
                    placeholder = { PlaceholderText(stringResource(R.string.name), textAlign) },
                    textStyle = textStyle
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.price,
                    onValueChange = { onDraftChange(draft.copy(price = it)) },
                    placeholder = { PlaceholderText(stringResource(R.string.price), textAlign) },
                    textStyle = textStyle
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.description,
                    onValueChange = { onDraftChange(draft.copy(description = it)) },
                    placeholder = { PlaceholderText(stringResource(R.string.description), textAlign) },
                    textStyle = textStyle
                )
                Spacer(modifier = Modifier.height(12.dp))
                Text(
                    text = stringResource(R.string.icon),
                    modifier = Modifier.fillMaxWidth(),
                    textAlign = textAlign,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.height(6.dp))
                IconPicker(
                    icon = draft.icon,
                    onIconChange = { onDraftChange(draft.copy(icon = it)) }
                )
            }
        },
        confirmButton = {
            Button(onClick = onAdd, enabled = draft.name.trim().isNotEmpty()) {
                Text(stringResource(R.string.add))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.cancel))
            }
        }
    )
}

@Composable
private fun BarcodeField(
    value: String,
    onValueChange: (String) -> Unit,
    textAlign: TextAlign,
    initiallyEditable: Boolean
) {
    var isEditable by remember(initiallyEditable) { mutableStateOf(initiallyEditable) }
    val clipboard = LocalClipboardManager.current
    val textStyle = LocalTextStyle.current.copy(textAlign = textAlign)

    Row(verticalAlignment = Alignment.CenterVertically) {
        TextField(
            value = value,
            onValueChange = onValueChange,
            modifier = Modifier.weight(1f),
            placeholder = { PlaceholderText(stringResource(R.string.barcode), textAlign) },
            textStyle = textStyle,
            enabled = isEditable,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
        )
        if (value.isNotBlank()) {
            IconButton(onClick = { clipboard.setText(AnnotatedString(value)) }) {
                Icon(imageVector = Icons.Default.ContentCopy, contentDescription = stringResource(R.string.copy))
            }
        }
        if (!isEditable) {
            TextButton(onClick = { isEditable = true }) {
                Text(stringResource(R.string.edit))
            }
        }
    }
}

@Composable
private fun IconPicker(
    icon: String,
    onIconChange: (String) -> Unit
) {
    val context = LocalContext.current
    val stockIcons = listOf("🧺", "🥛", "🍞", "🧀", "🍎", "🧴")

    val cameraLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.TakePicturePreview()
    ) { bitmap ->
        bitmap?.let { encodeIconBitmap(it) }?.let(onIconChange)
    }

    val libraryLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent()
    ) { uri ->
        uri?.let { loadBitmap(context, it) }?.let { encodeIconBitmap(it) }?.let(onIconChange)
    }

    Column {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            stockIcons.forEach { stock ->
                TextButton(onClick = { onIconChange(stock) }) {
                    Text(text = stock, fontSize = 20.sp)
                }
            }
        }
        Spacer(modifier = Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            OutlinedButton(onClick = { cameraLauncher.launch(null) }) {
                Icon(imageVector = Icons.Default.CameraAlt, contentDescription = null)
                Spacer(modifier = Modifier.width(6.dp))
                Text(stringResource(R.string.camera))
            }
            Spacer(modifier = Modifier.width(8.dp))
            OutlinedButton(onClick = { libraryLauncher.launch("image/*") }) {
                Icon(imageVector = Icons.Default.PhotoLibrary, contentDescription = null)
                Spacer(modifier = Modifier.width(6.dp))
                Text(stringResource(R.string.library))
            }
            Spacer(modifier = Modifier.weight(1f))
            if (icon.isNotBlank()) {
                TextButton(onClick = { onIconChange("") }) {
                    Text(stringResource(R.string.remove_icon))
                }
            }
        }

        if (icon.isNotBlank()) {
            ItemIconView(
                icon = icon,
                size = 48.dp,
                modifier = Modifier.padding(top = 8.dp)
            )
        }
    }
}

@Composable
private fun ItemIconView(
    icon: String,
    size: Dp,
    modifier: Modifier = Modifier
) {
    if (icon.isBlank()) return
    val image = remember(icon) { decodeIconImage(icon) }
    Box(
        modifier = modifier.size(size),
        contentAlignment = Alignment.Center
    ) {
        if (image != null) {
            Image(
                bitmap = image,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxSize()
                    .clip(RoundedCornerShape(6.dp))
            )
        } else {
            Text(text = icon, fontSize = (size.value * 0.9f).sp)
        }
    }
}

@Composable
private fun inputTextAlign(): TextAlign {
    return if (LocalLayoutDirection.current == LayoutDirection.Rtl) {
        TextAlign.End
    } else {
        TextAlign.Start
    }
}

@Composable
private fun PlaceholderText(text: String, textAlign: TextAlign) {
    Text(text = text, modifier = Modifier.fillMaxWidth(), textAlign = textAlign)
}

private fun decodeIconImage(icon: String): ImageBitmap? {
    if (!icon.startsWith("img:")) return null
    val payload = icon.removePrefix("img:")
    return try {
        val bytes = Base64.decode(payload, Base64.DEFAULT)
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size)?.asImageBitmap()
    } catch (_: IllegalArgumentException) {
        null
    }
}

private fun encodeIconBitmap(bitmap: Bitmap): String? {
    val resized = resizeBitmap(bitmap, 256)
    val output = ByteArrayOutputStream()
    if (!resized.compress(Bitmap.CompressFormat.JPEG, 80, output)) {
        return null
    }
    val base64 = Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
    return "img:$base64"
}

private fun resizeBitmap(bitmap: Bitmap, maxDimension: Int): Bitmap {
    val width = bitmap.width
    val height = bitmap.height
    val maxSide = maxOf(width, height)
    if (maxSide <= maxDimension) return bitmap
    val scale = maxDimension.toFloat() / maxSide.toFloat()
    val newWidth = (width * scale).toInt().coerceAtLeast(1)
    val newHeight = (height * scale).toInt().coerceAtLeast(1)
    return Bitmap.createScaledBitmap(bitmap, newWidth, newHeight, true)
}

private fun loadBitmap(context: Context, uri: Uri): Bitmap? {
    return try {
        context.contentResolver.openInputStream(uri)?.use { stream ->
            BitmapFactory.decodeStream(stream)
        }
    } catch (_: Exception) {
        null
    }
}
