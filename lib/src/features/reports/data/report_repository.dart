import '../../../data/api_client.dart';
import '../domain/report_summary.dart';

class ReportRepository {
  const ReportRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<ReportSummary> fetchSummary({
    required String childProfileId,
    required String range,
  }) async {
    final body =
        await _apiClient.get(
              '/api/reports/summary',
              queryParameters: {
                'childProfileId': childProfileId,
                'range': range,
              },
            )
            as Map<String, dynamic>?;

    final summary = body?['summary'];
    if (summary is! Map<String, dynamic>) {
      throw const ApiClientException(
        message: 'Report summary response was missing summary data',
      );
    }

    return ReportSummary.fromJson(summary);
  }

  Future<String> exportSummaryCsv({
    required String childProfileId,
    required String range,
  }) {
    return _apiClient.getText(
      '/api/reports/summary',
      queryParameters: {
        'childProfileId': childProfileId,
        'range': range,
        'format': 'csv',
      },
    );
  }
}
