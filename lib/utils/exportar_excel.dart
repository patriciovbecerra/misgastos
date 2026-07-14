import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:misgastos/models/gasto.dart';
import 'package:misgastos/utils/formato.dart';

class ExportarExcel {

  static Future<void> exportarGastos({
    required List<Gasto> gastos,
    required String periodoLabel,
  }) async {
    final excel = Excel.createExcel();

    // ─── Hoja 1: Detalle de gastos ───────────────────────────────────────────
    final hDetalle = excel['Gastos'];
    excel.setDefaultSheet('Gastos');

    // Estilo encabezado
    final estiloEnc = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    // Encabezados
    final encabezados = [
      'Fecha', 'Descripción', 'Categoría', 'Medio de Pago',
      'Monto Cuota', 'Monto Total', 'Cuota', 'Compartido', 'Grupo',
    ];
    for (var i = 0; i < encabezados.length; i++) {
      final cell = hDetalle.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(encabezados[i]);
      cell.cellStyle = estiloEnc;
    }

    // Filas de datos
    for (var i = 0; i < gastos.length; i++) {
      final g = gastos[i];
      final row = i + 1;
      _setStr(hDetalle, 0, row, Formato.fechaCorta(g.fecha));
      _setStr(hDetalle, 1, row, g.descripcion ?? g.categoria?.nombre ?? '');
      _setStr(hDetalle, 2, row, g.categoria?.nombre ?? '');
      _setStr(hDetalle, 3, row, g.medioPago?.nombre ?? '');
      _setNum(hDetalle, 4, row, g.valorCuota);
      _setNum(hDetalle, 5, row, g.monto);
      _setStr(hDetalle, 6, row,
          g.esCuotado ? 'C${g.cuotaNumero}/${g.cuotasTotal}' : 'Contado');
      _setStr(hDetalle, 7, row, g.esCompartido ? 'Sí' : 'No');
      _setStr(hDetalle, 8, row, g.grupo?.nombre ?? '');
    }

    // ─── Hoja 2: Resumen por medio de pago ───────────────────────────────────
    final hResumen = excel['Resumen'];

    // Título
    final titleCell = hResumen.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('Resumen — $periodoLabel');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#01579B'),
    );

    // Encabezado tabla resumen
    final estiloRes = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#E3F2FD'),
      fontColorHex: ExcelColor.fromHexString('#01579B'),
    );
    final encResumen = ['Medio de Pago', 'Cant. Gastos', 'Total Cuotas', 'Total Compras'];
    for (var i = 0; i < encResumen.length; i++) {
      final cell = hResumen.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 2));
      cell.value = TextCellValue(encResumen[i]);
      cell.cellStyle = estiloRes;
    }

    // Agrupar por medio de pago
    final Map<String, List<Gasto>> porMedio = {};
    for (final g in gastos) {
      final nombre = g.medioPago?.nombre ?? 'Sin medio';
      porMedio.putIfAbsent(nombre, () => []).add(g);
    }

    var row = 3;
    double totalGenCuotas = 0;
    double totalGenCompras = 0;

    for (final entry in porMedio.entries) {
      final totalCuotas = entry.value.fold(0.0, (s, g) => s + g.valorCuota);
      final totalCompras = entry.value.fold(0.0, (s, g) => s + g.monto);
      totalGenCuotas += totalCuotas;
      totalGenCompras += totalCompras;

      _setStr(hResumen, 0, row, entry.key);
      _setNum(hResumen, 1, row, entry.value.length.toDouble());
      _setNum(hResumen, 2, row, totalCuotas);
      _setNum(hResumen, 3, row, totalCompras);
      row++;
    }

    // Fila total
    final estiloTotal = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    final tLabel = hResumen.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row));
    tLabel.value = TextCellValue('TOTAL');
    tLabel.cellStyle = estiloTotal;

    final tCant = hResumen.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row));
    tCant.value = IntCellValue(gastos.length);
    tCant.cellStyle = estiloTotal;

    final tCuotas = hResumen.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row));
    tCuotas.value = DoubleCellValue(totalGenCuotas);
    tCuotas.cellStyle = estiloTotal;

    final tCompras = hResumen.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row));
    tCompras.value = DoubleCellValue(totalGenCompras);
    tCompras.cellStyle = estiloTotal;

    // ─── Guardar y compartir ─────────────────────────────────────────────────
    final bytes = excel.encode();
    if (bytes == null) throw Exception('No se pudo generar el Excel');

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final nombre =
        'AlDia_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.xlsx';
    final file = File('${dir.path}/$nombre');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Al Día — Gastos $periodoLabel',
    );
  }

  static void _setStr(Sheet sheet, int col, int row, String value) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = TextCellValue(value);
  }

  static void _setNum(Sheet sheet, int col, int row, double value) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
        .value = DoubleCellValue(value);
  }
}
