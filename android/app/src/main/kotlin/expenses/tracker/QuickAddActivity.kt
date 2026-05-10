package expenses.tracker

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.os.Bundle
import android.view.View
import android.widget.*

class QuickAddActivity : Activity() {

    private var isIncome = false
    private val expenseCategories = arrayOf("Food", "Transport", "Shopping", "Bills", "Entertainment", "Health", "Education", "Other")
    private val incomeCategories = arrayOf("Salary", "Freelance", "Gift", "Investment", "Other")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_quick_add)

        val editAmount = findViewById<EditText>(R.id.edit_amount)
        val editNote = findViewById<EditText>(R.id.edit_note)
        val spinnerCategory = findViewById<Spinner>(R.id.spinner_category)
        val btnExpense = findViewById<Button>(R.id.btn_expense)
        val btnIncome = findViewById<Button>(R.id.btn_income)
        val btnCancel = findViewById<Button>(R.id.btn_cancel)
        val btnSave = findViewById<Button>(R.id.btn_save)

        // Setup category spinner
        fun updateSpinner() {
            val cats = if (isIncome) incomeCategories else expenseCategories
            val adapter = ArrayAdapter(this, android.R.layout.simple_spinner_item, cats)
            adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
            spinnerCategory.adapter = adapter
        }
        updateSpinner()

        // Toggle buttons
        fun updateToggle() {
            if (isIncome) {
                btnIncome.setTextColor(Color.parseColor("#3FB950"))
                btnExpense.setTextColor(Color.parseColor("#8B949E"))
                btnSave.text = "Add Income"
            } else {
                btnExpense.setTextColor(Color.parseColor("#F85149"))
                btnIncome.setTextColor(Color.parseColor("#8B949E"))
                btnSave.text = "Expenses Tracker"
            }
            updateSpinner()
        }

        btnExpense.setOnClickListener {
            isIncome = false
            updateToggle()
        }
        btnIncome.setOnClickListener {
            isIncome = true
            updateToggle()
        }

        btnCancel.setOnClickListener { finish() }

        btnSave.setOnClickListener {
            val amountStr = editAmount.text.toString().trim()
            val amount = amountStr.toDoubleOrNull()
            if (amount == null || amount <= 0) {
                editAmount.error = "Enter a valid amount"
                return@setOnClickListener
            }
            val category = spinnerCategory.selectedItem?.toString() ?: "Other"
            val note = editNote.text.toString().trim()

            // Save pending transaction to SharedPreferences
            val prefs = getSharedPreferences("pending_transactions", Context.MODE_PRIVATE)
            val count = prefs.getInt("count", 0)
            val newCount = count + 1
            prefs.edit().apply {
                putString("txn_${newCount}_type", if (isIncome) "income" else "expense")
                putString("txn_${newCount}_amount", amount.toString())
                putString("txn_${newCount}_category", category)
                putString("txn_${newCount}_note", note)
                putString("txn_${newCount}_date", System.currentTimeMillis().toString())
                putInt("count", newCount)
                apply()
            }

            Toast.makeText(this, "${if (isIncome) "Income" else "Expense"} saved! ✓", Toast.LENGTH_SHORT).show()
            finish()
        }

        // Auto-focus amount
        editAmount.requestFocus()
    }
}
