module Billing
  module Queries
    class ListBudgets
      def self.call(page:, per_page:, status: nil)
        scope = Entities::Budget.includes(:items, :payments).order(created_at: :desc, id: :desc)
        scope = scope.where(status: status) if status.present?

        total   = scope.count
        records = scope.offset((page - 1) * per_page).limit(per_page)

        Result.success(payload: { budgets: records, total: total })
      end
    end
  end
end
