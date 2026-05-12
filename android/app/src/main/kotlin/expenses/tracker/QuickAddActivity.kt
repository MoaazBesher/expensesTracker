package expenses.tracker

import android.app.Activity
import android.content.Context
import android.graphics.Color
import android.os.Bundle
import android.view.WindowManager
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.Spinner
import android.widget.Toast
import java.util.concurrent.Executors

class QuickAddActivity : Activity() {

    private var isIncome = false
    private val expenseCategories = arrayOf(
        "Food", "Transport", "Shopping", "Bills", "Entertainment",
        "Health", "Education", "Other",
    )
    private val incomeCategories = arrayOf(
        "Salary", "Freelance", "Gift", "Investment", "Other",
    )

    private val saveExecutor = Executors.newSingleThreadExecutor()

    private lateinit var editAmount: EditText
    private lateinit var editNote: EditText
    private lateinit var spinnerCategory: Spinner
    private lateinit var btnExpense: Button
    private lateinit var btnIncome: Button
    private lateinit var btnCancel: Button
    private lateinit var btnSave: Button

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE)
        setContentView(R.layout.activity_quick_add)

        editAmount = findViewById(R.id.edit_amount)
        editNote = findViewById(R.id.edit_note)
        spinnerCategory = findViewById(R.id.spinner_category)
        btnExpense = findViewById(R.id.btn_expense)
        btnIncome = findViewById(R.id.btn_income)
        btnCancel = findViewById(R.id.btn_cancel)
        btnSave = findViewById(R.id.btn_save)

        fun updateSpinner() {
            val cats = if (isIncome) incomeCategories else expenseCategories
            val adapter = ArrayAdapter(this, R.layout.spinner_item_text, cats)
            adapter.setDropDownViewResource(R.layout.spinner_item_text)
            spinnerCategory.adapter = adapter
        }

        fun updateToggle() {
            if (isIncome) {
                btnIncome.setBackgroundResource(R.drawable.quick_add_toggle_income_on)
                btnExpense.setBackgroundResource(R.drawable.quick_add_toggle_unselected)
                btnIncome.setTextColor(Color.parseColor("#3FB950"))
                btnExpense.setTextColor(Color.parseColor("#8B949E"))
                btnSave.text = getString(R.string.quick_add_save_income)
            } else {
                btnExpense.setBackgroundResource(R.drawable.quick_add_toggle_expense_on)
                btnIncome.setBackgroundResource(R.drawable.quick_add_toggle_unselected)
                btnExpense.setTextColor(Color.parseColor("#F85149"))
                btnIncome.setTextColor(Color.parseColor("#8B949E"))
                btnSave.text = getString(R.string.quick_add_save_expense)
            }
            updateSpinner()
        }

        updateToggle()

        btnExpense.setOnClickListener {
            isIncome = false
            updateToggle()
        }
        btnIncome.setOnClickListener {
            isIncome = true
            updateToggle()
        }

        btnCancel.setOnClickListener { finish() }

        editAmount.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_NEXT) {
                spinnerCategory.requestFocusFromTouch()
                true
            } else {
                false
            }
        }

        editNote.setOnEditorActionListener { _, actionId, _ ->
            if (actionId == EditorInfo.IME_ACTION_DONE) {
                hideKeyboard()
                true
            } else {
                false
            }
        }

        btnSave.setOnClickListener {
            if (!btnSave.isEnabled) return@setOnClickListener
            val amountStr = editAmount.text.toString().trim()
            val amount = amountStr.toDoubleOrNull()
            if (amount == null || amount <= 0) {
                editAmount.error = getString(R.string.quick_add_amount_error)
                return@setOnClickListener
            }
            val category = spinnerCategory.selectedItem?.toString() ?: "Other"
            val note = editNote.text.toString().trim()
            val capturedAt = System.currentTimeMillis()

            btnSave.isEnabled = false
            btnCancel.isEnabled = false
            hideKeyboard()

            saveExecutor.execute {
                try {
                    val prefs = getSharedPreferences("pending_transactions", Context.MODE_PRIVATE)
                    val count = prefs.getInt("count", 0)
                    val newCount = count + 1
                    prefs.edit().apply {
                        putString("txn_${newCount}_type", if (isIncome) "income" else "expense")
                        putString("txn_${newCount}_amount", amount.toString())
                        putString("txn_${newCount}_category", category)
                        putString("txn_${newCount}_note", note)
                        putString("txn_${newCount}_date", capturedAt.toString())
                        putInt("count", newCount)
                        apply()
                    }
                    runOnUiThread {
                        Toast.makeText(
                            this,
                            if (isIncome) {
                                getString(R.string.quick_add_toast_income)
                            } else {
                                getString(R.string.quick_add_toast_expense)
                            },
                            Toast.LENGTH_SHORT,
                        ).show()
                        finish()
                    }
                } catch (_: Exception) {
                    runOnUiThread {
                        btnSave.isEnabled = true
                        btnCancel.isEnabled = true
                        Toast.makeText(this, R.string.quick_add_save_error, Toast.LENGTH_SHORT).show()
                    }
                }
            }
        }

        editAmount.requestFocus()
    }

    private fun hideKeyboard() {
        val imm = getSystemService(INPUT_METHOD_SERVICE) as? InputMethodManager ?: return
        currentFocus?.let { imm.hideSoftInputFromWindow(it.windowToken, 0) }
    }

    override fun onDestroy() {
        saveExecutor.shutdown()
        super.onDestroy()
    }
}
