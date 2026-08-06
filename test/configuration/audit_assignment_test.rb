require "test_helper"

# 監査の割り当て。
#
# 状態を変える入口は、記録するか・しないかを必ず持つ。宣言を義務にしないと、
# 記録の無い入口と、記録すべきなのに書き忘れた入口を区別できない。
#
# 見るのは経路の一覧そのものとする。制御部の側から数えると、経路の付いて
# いない動作まで数え、経路だけあって動作の無い入口を見落とす。
#
# この検査が確かめるのは割り当ての網羅である。記録すると宣言した入口が実際に
# 記録することは、その入口ごとのテストが受け持つ。
class AuditAssignmentTest < ActiveSupport::TestCase
  MUTATING = /POST|PATCH|PUT|DELETE/

  test "状態を変える入口が 1 つ以上ある" do
    assert_operator entries.size, :>=, 1
  end

  test "状態を変える入口はすべて割り当てを持つ" do
    missing = entries.reject { |entry| entry[:assignment] }

    assert_empty missing.map { |entry| "#{entry[:controller]}##{entry[:action]}" },
                 "records_audit か records_no_audit のどちらかを宣言する"
  end

  test "記録しない入口は理由を持つ" do
    entries.each do |entry|
      next if entry[:assignment] == :recorded

      assert_operator entry[:assignment].to_s.strip.length, :>, 0,
                      "#{entry[:controller]}##{entry[:action]} の理由が空である"
    end
  end

  test "記録する入口と記録しない入口の両方がある" do
    # 片方だけになっていれば、宣言が形だけになっている。
    assignments = entries.map { |entry| entry[:assignment] == :recorded }

    assert_includes assignments, true
    assert_includes assignments, false
  end

  test "記録する動作の名前は、記録が受け付ける一覧の中にある" do
    used = Rails.root.glob("app/{controllers,models}/**/*.rb").flat_map do |path|
      path.read.scan(/record_audit_event\(\s*"([a-z_]+)"/).flatten +
        path.read.scan(/audit:\s*"([a-z_]+)"/).flatten
    end.uniq

    assert_empty used - AuditEvent::ACTIONS
  end

  private
    def entries
      @entries ||= Rails.application.routes.routes.filter_map do |route|
        next unless route.verb.to_s.match?(MUTATING)

        controller = route.defaults[:controller]
        action = route.defaults[:action]
        next if controller.nil? || action.nil?

        klass = "#{controller}_controller".camelize.safe_constantize
        next if klass.nil? || !klass.respond_to?(:audit_assignment_for)

        { controller: controller, action: action, assignment: klass.audit_assignment_for(action) }
      end.uniq { |entry| [ entry[:controller], entry[:action] ] }
    end
end
