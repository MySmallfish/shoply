package com.shoply.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.widget.Toast
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.CameraAlt
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInAccount
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
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
            text = "Shoply",
            fontSize = 36.sp,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Shared lists that update in real time",
            color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.6f)
        )
        Spacer(modifier = Modifier.height(32.dp))

        Button(
            onClick = { if (activity != null) launcher.launch(googleClient.signInIntent) },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Continue with Google")
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
    var adjustAmount by remember { mutableStateOf("") }
    var adjustDefaultAmount by remember { mutableStateOf(1) }
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
        adjustDefaultAmount = defaultAmount
        adjustAmount = defaultAmount.toString()
    }

    LaunchedEffect(scanCode) {
        val code = scanCode ?: return@LaunchedEffect
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
            message = if (action.wasBought) "Marked unbought" else "Marked bought",
            actionLabel = "Undo",
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
                        Icon(imageVector = Icons.Default.Group, contentDescription = "Members")
                    }
                    IconButton(onClick = { showInvite = true }) {
                        Icon(imageVector = Icons.Default.PersonAdd, contentDescription = "Invite")
                    }
                    IconButton(onClick = { showPendingInvites = true }) {
                        Icon(imageVector = Icons.Default.Email, contentDescription = "Pending invitations")
                    }
                    IconButton(onClick = { viewModel.signOut() }) {
                        Icon(imageVector = Icons.Default.PowerSettingsNew, contentDescription = "Sign out")
                    }
                }
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) },
        floatingActionButton = {
            FloatingActionButton(onClick = { showScanner = true }) {
                Icon(imageVector = Icons.Default.CameraAlt, contentDescription = "Scan")
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
                            viewModel.addItem(
                                trimmed,
                                match?.barcode,
                                match?.price,
                                match?.description,
                                match?.icon
                            )
                            newItemName = ""
                            selectedSuggestion = null
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
                                text = "Add your first item to start",
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
                        context.startActivity(Intent.createChooser(shareIntent, "Share invite link"))
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
            title = { Text("Merge lists?") },
            text = {
                Text(
                    "You already have a list named \"${prompt.existingListTitle}\". " +
                        "Merge it into \"${prompt.invitedListTitle}\"?"
                )
            },
            confirmButton = {
                TextButton(onClick = { viewModel.mergeInvitedList(prompt) }) {
                    Text("Merge")
                }
            },
            dismissButton = {
                TextButton(onClick = { viewModel.keepInviteSeparate(prompt) }) {
                    Text("Keep Separate")
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
                val amount = adjustAmount.trim().toIntOrNull() ?: adjustDefaultAmount
                if (amount > 0) {
                    val delta = if (adjustMode == QuantityMode.BOUGHT) -amount else amount
                    viewModel.adjustQuantity(item, delta)
                }
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
            if (!item.icon.isNullOrBlank()) {
                Text(
                    text = item.icon,
                    modifier = Modifier.padding(end = 6.dp)
                )
            }
            Text(
                text = item.name,
                color = MaterialTheme.colorScheme.onBackground
            )
        }
        IconButton(onClick = onDecrement) {
            Icon(imageVector = Icons.Default.Remove, contentDescription = "Decrease")
        }
        Text(
            text = item.quantity.toString(),
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.widthIn(min = 20.dp)
        )
        IconButton(onClick = onIncrement) {
            Icon(imageVector = Icons.Default.Add, contentDescription = "Increase")
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
            placeholder = { Text("Add item") },
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
            Icon(imageVector = Icons.Default.Edit, contentDescription = "Details")
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
    val currentTitle = lists.firstOrNull { it.id == selectedListId }?.title ?: "Lists"

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
                text = { Text("New List") },
                onClick = {
                    expanded = false
                    onCreate()
                }
            )
            androidx.compose.material3.DropdownMenuItem(
                text = { Text("Join with Link") },
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

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Invite") },
        text = {
            Column {
                TextField(
                    value = email,
                    onValueChange = { email = it },
                    placeholder = { Text("Email") }
                )
                Spacer(modifier = Modifier.height(12.dp))
                Box {
                    TextButton(onClick = { roleExpanded = true }) {
                        Text("Role: ${role.replaceFirstChar { it.uppercase() }}")
                    }
                    androidx.compose.material3.DropdownMenu(
                        expanded = roleExpanded,
                        onDismissRequest = { roleExpanded = false }
                    ) {
                        androidx.compose.material3.DropdownMenuItem(
                            text = { Text("Editor") },
                            onClick = { role = "editor"; roleExpanded = false }
                        )
                        androidx.compose.material3.DropdownMenuItem(
                            text = { Text("Viewer") },
                            onClick = { role = "viewer"; roleExpanded = false }
                        )
                    }
                }
            }
        },
        confirmButton = {
            Button(onClick = { onSend(email, role) }, enabled = email.trim().isNotEmpty()) {
                Text("Send")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@Composable
private fun CreateListDialog(onDismiss: () -> Unit, onCreate: (String) -> Unit) {
    var title by remember { mutableStateOf("") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("New List") },
        text = {
            TextField(
                value = title,
                onValueChange = { title = it },
                placeholder = { Text("e.g. Grocery") }
            )
        },
        confirmButton = {
            Button(onClick = { onCreate(title) }, enabled = title.trim().isNotEmpty()) {
                Text("Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
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
                Text("Members", style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(12.dp))

                if (members.isEmpty()) {
                    Text("No members found", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
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
                    Text("Invites", style = MaterialTheme.typography.titleLarge)
                    Spacer(modifier = Modifier.height(8.dp))
                    if (invites.isEmpty()) {
                        Text("No pending invites", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
                    } else {
                        Column {
                            invites.forEach { invite ->
                                InviteRow(invite = invite, onRevoke = { onRevoke(invite.id) })
                            }
                        }
                    }
                } else {
                    Text(
                        "Only the list owner can manage members and invites.",
                        color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Done")
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
                Text("Pending Invitations", style = MaterialTheme.typography.titleLarge)
                Spacer(modifier = Modifier.height(12.dp))

                if (invites.isEmpty()) {
                    Text("No pending invitations", color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f))
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
                        Text("Done")
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
            Text(invite.listTitle, fontWeight = FontWeight.SemiBold)
            Text(
                roleLabel(invite.role),
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }

        Button(onClick = onAccept) {
            Text("Accept")
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
                        "You",
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
                    Icon(imageVector = Icons.Default.MoreVert, contentDescription = "Manage member")
                }
                androidx.compose.material3.DropdownMenu(
                    expanded = menuOpen,
                    onDismissRequest = { menuOpen = false }
                ) {
                    androidx.compose.material3.DropdownMenuItem(
                        text = { Text("Make Editor") },
                        onClick = {
                            menuOpen = false
                            onRoleChange("editor")
                        }
                    )
                    androidx.compose.material3.DropdownMenuItem(
                        text = { Text("Make Viewer") },
                        onClick = {
                            menuOpen = false
                            onRoleChange("viewer")
                        }
                    )
                    Divider()
                    androidx.compose.material3.DropdownMenuItem(
                        text = { Text("Remove") },
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
                "${roleLabel(invite.role)} • ${invite.status}",
                fontSize = 12.sp,
                color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.6f)
            )
        }

        if (invite.status == "pending") {
            TextButton(onClick = onRevoke) {
                Text("Revoke")
            }
        }
    }
}

private fun roleLabel(role: String): String {
    return when (role) {
        "owner" -> "Owner"
        "editor" -> "Editor"
        else -> "Viewer"
    }
}

@Composable
private fun JoinListDialog(onDismiss: () -> Unit, onJoin: (String) -> Unit) {
    var input by remember { mutableStateOf("") }
    val token = extractToken(input)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Join List") },
        text = {
            TextField(
                value = input,
                onValueChange = { input = it },
                placeholder = { Text("Paste invite link") }
            )
        },
        confirmButton = {
            Button(onClick = { token?.let(onJoin) }, enabled = !token.isNullOrBlank()) {
                Text("Join")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
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
                        if (!item.icon.isNullOrBlank()) {
                            Text(text = item.icon)
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
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Item Details") },
        text = {
            Column {
                TextField(
                    value = draft.name,
                    onValueChange = { onDraftChange(draft.copy(name = it)) },
                    placeholder = { Text("Name") }
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.barcode,
                    onValueChange = { onDraftChange(draft.copy(barcode = it)) },
                    placeholder = { Text("Barcode") },
                    enabled = allowBarcodeEdit
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.price,
                    onValueChange = { onDraftChange(draft.copy(price = it)) },
                    placeholder = { Text("Price") }
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.icon,
                    onValueChange = { onDraftChange(draft.copy(icon = it)) },
                    placeholder = { Text("Icon") }
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.description,
                    onValueChange = { onDraftChange(draft.copy(description = it)) },
                    placeholder = { Text("Description") }
                )
            }
        },
        confirmButton = {
            Button(onClick = onSave, enabled = draft.name.trim().isNotEmpty()) {
                Text("Save")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}

@Composable
private fun AdjustQuantityDialog(
    item: ShoppingItem,
    mode: QuantityMode,
    amount: String,
    onModeChange: (QuantityMode) -> Unit,
    onAmountChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onApply: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("How much did you buy?") },
        text = {
            Column {
                Text("Left to buy: ${item.quantity}", color = MaterialTheme.colorScheme.onBackground.copy(alpha = 0.7f))
                Spacer(modifier = Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (mode == QuantityMode.BOUGHT) {
                        Button(onClick = { onModeChange(QuantityMode.BOUGHT) }) {
                            Text("Bought")
                        }
                        OutlinedButton(onClick = { onModeChange(QuantityMode.NEED) }) {
                            Text("Need")
                        }
                    } else {
                        OutlinedButton(onClick = { onModeChange(QuantityMode.BOUGHT) }) {
                            Text("Bought")
                        }
                        Button(onClick = { onModeChange(QuantityMode.NEED) }) {
                            Text("Need")
                        }
                    }
                }
                Spacer(modifier = Modifier.height(12.dp))
                TextField(
                    value = amount,
                    onValueChange = onAmountChange,
                    placeholder = { Text("Amount") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number, imeAction = ImeAction.Done)
                )
            }
        },
        confirmButton = {
            Button(onClick = onApply) {
                Text("Apply")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
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
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add Item") },
        text = {
            Column {
                Text("Scanned: $barcode", fontWeight = FontWeight.SemiBold)
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.name,
                    onValueChange = { onDraftChange(draft.copy(name = it)) },
                    placeholder = { Text("Name") }
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.price,
                    onValueChange = { onDraftChange(draft.copy(price = it)) },
                    placeholder = { Text("Price") }
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.icon,
                    onValueChange = { onDraftChange(draft.copy(icon = it)) },
                    placeholder = { Text("Icon") }
                )
                Spacer(modifier = Modifier.height(8.dp))
                TextField(
                    value = draft.description,
                    onValueChange = { onDraftChange(draft.copy(description = it)) },
                    placeholder = { Text("Description") }
                )
            }
        },
        confirmButton = {
            Button(onClick = onAdd, enabled = draft.name.trim().isNotEmpty()) {
                Text("Add")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("Cancel")
            }
        }
    )
}
