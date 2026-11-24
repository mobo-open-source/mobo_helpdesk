import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:mobo_helpdesk/features/tickets/presentation/bloc/ticket_bloc.dart';

import '../../../../app/themes/app_colors.dart';
import '../../../../core/widgets/dialog_button_style.dart';
import '../../../../core/widgets/edit_dropdown_field.dart';

class CovertOpportunityDialogWidget extends StatefulWidget {
  final BuildContext context;
  final int ticketId;
  final VoidCallback? onSuccess;

  const CovertOpportunityDialogWidget({
    super.key,
    required this.context,
    required this.ticketId,
    this.onSuccess,
  });

  @override
  State<CovertOpportunityDialogWidget> createState() =>
      _CovertOpportunityDialogWidgetState();
}

class _CovertOpportunityDialogWidgetState
    extends State<CovertOpportunityDialogWidget> {
  String? errorMessage;
  bool isExistCustomer = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[800] : Colors.white,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Convert to Opportunity',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: BlocBuilder<TicketBloc, TicketState>(
            builder: (context, state) {
              isExistCustomer = state.selectedOpportunityCustomer == 'exist';
              return Stack(
                children: [
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.95,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            EditDropdownField(
                              fieldName: "Customer",
                              items: [
                                {
                                  "id": "create",
                                  "label": "Create a new customer",
                                },
                                {
                                  "id": "exist",
                                  "label": "Link to an existing customer",
                                },
                                {
                                  "id": "nothing",
                                  "label": "Do not link to a customer",
                                },
                              ],
                              selectionValue: state.selectedOpportunityCustomer,
                              isFieldEdit: true,
                              isSelection: true,
                              onSelectionChanged: (value) {
                                setState(() {
                                  isExistCustomer = value == 'exist';
                                });
                                context.read<TicketBloc>().add(
                                  UpdateSelectedOpportunityCustomer(value),
                                );
                              },
                            ),

                            if (isExistCustomer) ...[
                              SizedBox(height: 10),
                              EditDropdownField(
                                fieldName: "Customer",
                                items: state.partners ?? [],
                                value: state.selectedOpportunityPartner,
                                isFieldEdit: true,
                                idNotNameShow: true,
                                onChanged: (value) {
                                  context.read<TicketBloc>().add(
                                    UpdateSelectedOpportunityPartner(value),
                                  );
                                },
                              ),
                            ],
                            SizedBox(height: 20),
                            EditDropdownField(
                              fieldName: "Sales Team",
                              items: state.salesTeam ?? [],
                              value: state.selectedOpportunityTeam,
                              isFieldEdit: true,
                              onChanged: (value) {
                                context.read<TicketBloc>().add(
                                  UpdateSelectedOpportunitySalesTeam(value),
                                );
                              },
                            ),
                            SizedBox(height: 20),
                            EditDropdownField(
                              fieldName: "Salesperson",
                              items: state.users ?? [],
                              value: state.selectedOpportunitySalesPerson,
                              isFieldEdit: true,
                              onChanged: (value) {
                                context.read<TicketBloc>().add(
                                  UpdateSelectedOpportunitySalesPerson(value),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (state.isLoading)
                    Positioned.fill(
                      child: Center(
                        child: LoadingAnimationWidget.fourRotatingDots(
                          color: AppColors.primary,
                          size: 50,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          actions: [
            BlocBuilder<TicketBloc, TicketState>(
              builder: (context, state) {
                return Row(
                  children: [
                    Expanded(
                      child: DialogButtonStyle.negativeButton(
                        context: context,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        title: 'Cancel',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DialogButtonStyle.successButton(
                        onPressed: () async {
                          final bloc = context.read<TicketBloc>();

                          bloc.add(
                            ConvertOpportunity({
                              'ticket_id': widget.ticketId,
                              'action': state.selectedOpportunityCustomer,
                              'partner_id': state.selectedOpportunityPartner,
                              'team_id': state.selectedOpportunityTeam,
                              'user_id': state.selectedOpportunitySalesPerson,
                            }),
                          );

                          Navigator.pop(context);
                        },
                        title: "Continue",
                        context: context,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
