import 'package:flutter_test/flutter_test.dart';
import 'package:control_tuk_tuk/main.dart';
void main(){
 test('separates debt, commercial available and withdrawal minimum',(){
 final p=MarketplaceWalletTransition.fromMap({'active':true,'debt_cup':400,'cash_balance':0,'promotional_balance':100,'impulsa_balance':5000,'impulsa_available':4000,'withdrawal_minimum_cup':5000,'withdrawal_reserved':1000,'can_withdraw':false,'withdrawals':[{'id':'w','amount':1000,'status':'requested'}]});
 expect(p.debt,400);expect(p.available,4000);expect(p.minimum,5000);expect(p.canWithdraw,false);expect(p.withdrawals.single.status,'requested');
 });
 test('credit offer only when eligible with missing commission',(){
 final p=MarketplaceAvailableJob.fromMap({'job_id':'j','final_price':1000,'commission_amount':150,'commission_rate':0.15,'missing_balance':150,'can_accept':true});
 expect(p.usesInitialCredit,true);expect(p.commissionAmount,150);
 expect(MarketplaceAvailableJob.fromMap({'commission_amount':150,'missing_balance':150,'can_accept':false}).usesInitialCredit,false);
 expect(MarketplaceAvailableJob.fromMap({}).canAccept,isNull);
 });
}
